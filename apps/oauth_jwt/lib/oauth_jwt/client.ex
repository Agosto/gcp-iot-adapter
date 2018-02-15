defmodule OauthJwt.Client do
  require Logger
  import OauthJwt.Common
  use GenServer

  @auth_token_url "https://www.googleapis.com/oauth2/v3/token"
  @cache :oauth_jwt_cache

  @google_metadata_server "http://metadata"
  @google_metadata_header {"Metadata-Flavor", "Google"}
  @google_metadata_access_token_url "/computeMetadata/v1/instance/service-accounts/default/token"

  defmodule OauthJwt.Client.GceClientInfo do
    defstruct type: :gce, claims: %{}, jwt: "", key: ""
  end

  defmodule OauthJwt.Client.JwtClientInfo do
    defstruct type: :jwt, claims: %{}, jwt: "", key: ""
  end

  defmodule OauthJwt.Client.State do
    defstruct initialized: false,
      client_info: nil,
      cache: nil,
      access_token: nil,
      refresh_timer: nil,
      auth_token_url: nil,
      google_metadata_server: nil
  end
  def start_link(opts \\ [], server_opts \\ []) do
       GenServer.start_link(__MODULE__, opts, server_opts)
  end

  def generate_iat_exp() do
    iat = :erlang.system_time 1
    exp = iat + 3600
    %{"iat" => iat, "exp" => exp}
  end

  def get_jwt(pid) do
    GenServer.call(pid, :get_jwt)
  end

  def get_access_token(pid) do
    # access_token = case :ets.lookup(@cache, "access_token") do
    #   [{:access_token, access_token}] -> access_token
    #   _ -> GenServer.call(pid, :get_access_token)
    # end
    # if access_token == nil do
    #   throw(:bad_token)  # FIXME: figure out reasonable payload
    # end
    # access_token
    GenServer.call(pid, :get_access_token)
  end

  def force_refresh(pid) do
    GenServer.call(pid, :force_refresh)
  end

  defp generate_claims(iss, scope) do
    claims = %{"iss" => iss,
      "scope" => scope,
      "aud" => @auth_token_url}
      |> Map.merge(generate_iat_exp)

     Logger.debug "JWT claims: #{inspect claims}"
     claims
  end

  defp sign(claims, key) do
    claims |> JsonWebToken.sign(%{alg: "RS256", key: JsonWebToken.Algorithm.RsaUtil.private_key(key)})
  end

  defp update_expired_jwt(state) do
    new_state = case state do
      :jwt -> updated_claims = Map.merge(state.client_info.claims, generate_iat_exp())
              jwt = sign(updated_claims, state.client_info.key)
              client_info = %{state.client_info | claims: updated_claims, jwt: jwt}
              %{state | client_info: client_info}
      _ -> state
    end
    new_state
  end

  defp use_default_service_account?() do
    Application.get_env(:oauth_jwt, :use_default_service_account) == true
  end

  defp determine_client_type(_state) do
    if use_default_service_account?() and on_gce?() do
      :gce
    else
      :jwt
    end
  end

  defp create_client_info(:jwt) do
    Logger.debug "Creating new jwt"
    {:ok, secrets} = try_load_secrets()
    key = secrets["private_key"]
    claims = generate_claims(secrets["client_email"], "https://www.googleapis.com/auth/pubsub")
    jwt = sign(claims, key)
    %OauthJwt.Client.JwtClientInfo{claims: claims, jwt: jwt, key: key}
  end

  defp create_client_info(:gce) do
    %OauthJwt.Client.GceClientInfo{}
  end

  defp do_initialize(state) do
    Logger.debug "Starting OAuth..."
    client_info = create_client_info(determine_client_type(state))
    state = %{state | client_info: client_info}
    state = case retrieve_and_cache_access_token(state) do
      {:ok, state} -> state
      _ -> state
    end
    %{state | initialized: true, client_info: client_info}
  end

  defp check_initialized(state) do
    case state.initialized do
      false -> do_initialize(state)
      _ -> state
    end
  end

  def get_auth_header(pid) do
    access_token = get_access_token(pid)
    {"Authorization", "Bearer " <> access_token}
  end

  def do_request(pid, method, url, body, headers, options) do
    headers = [get_auth_header(pid) | headers]
    #IO.puts "Doing request: #{method} #{url}"
    #IO.puts "Body: #{body}"
    do_request(pid, method, url, body, headers, options, 1, 3)
  end

  @doc """
  Repeated attempts are for oauth2 failures; request will get new
  bearer token and try again.
  """
  def do_request(pid, method, url, body, headers, options, attempt, max_attempts) do

    case HTTPoison.request(method, url, body, headers, options) do
      #response = %{status_code: status_code} when status >= 200 and status <= 299 ->
      #  {:ok, response}
      {:ok, %{status_code: status_code}} when status_code == 401 and attempt <= max_attempts ->
        {_, bearer_token} = get_auth_header(pid)
        headers = headers |> Enum.into(Map.new) |> Map.put("Authorization", bearer_token) |> Map.to_list
        :timer.sleep(:timer.seconds(1*attempt))
        do_request(pid, method, url, body, headers, options, attempt+1, max_attempts)
      {:error, error} ->
        :timer.sleep(:timer.seconds(1*attempt))
        do_request(pid, method, url, body, headers, options, attempt+1, max_attempts)
      response -> response
    end
  end


  ## GenServer
   def init(opts) do
     Logger.info "init: " <> inspect(opts)
     auth_token_url = opts[:auth_token_url_override] || @auth_token_url
     Logger.info "auth_token_url: " <> inspect(auth_token_url)
     google_metadata_server = opts[:google_metadata_server_override] || @google_metadata_server
     Logger.info(auth_token_url)
     #cache = :ets.new(:oauth_jwt_cache, [:public, read_concurrency: true])
     {:ok, %OauthJwt.Client.State{auth_token_url: auth_token_url, google_metadata_server: google_metadata_server}}
   end

   defp clear_refresh_timer(refresh_timer) do
     case refresh_timer do
       nil ->
         Logger.debug "No refresh_timer in state..."
       timer_reference ->
         Logger.debug "Deleting old access token refresh timer"
         :erlang.cancel_timer(timer_reference)
     end
   end

   defp schedule_refresh(expires_in) do
     refresh_time = expires_in * 1000 - (30*1000)
     Logger.debug "Scheduling refresh of access token in #{inspect refresh_time} milliseconds"
     Process.send_after(self(), :refresh_token, refresh_time)
   end

   defp update_refresh_timer(prev_refresh_timer, expires_in) do
     clear_refresh_timer(prev_refresh_timer)
     schedule_refresh(expires_in)
   end

   defp handle_access_token_response({:ok, %{body: body, status_code: 200}}, state) do
     resp = Poison.decode!(body)
     access_token = resp["access_token"]
     #:ets.insert(@cache, {"access_token", access_token})
     refresh_timer = update_refresh_timer(state.refresh_timer, resp["expires_in"])
     state = %{state | :access_token => access_token, :refresh_timer => refresh_timer}
     {:ok, state}
   end

   defp handle_access_token_response({status, response}, _) do
     Logger.error "Failed to retrieve access token (status #{status}): #{inspect response}"
     {:error, response}
   end

   defp retrieve_and_cache_access_token(state=%{client_info: %{type: :gce}}) do
     # nil jwt indicates on gce vm so we can access metadata server for access token
     Logger.info "Getting bearer token from metadata server"
     HTTPoison.get(state.google_metadata_server <> @google_metadata_access_token_url, [@google_metadata_header])
     |> handle_access_token_response(state)
   end

   defp retrieve_and_cache_access_token(state=%{client_info: %{type: :jwt}}) do
     client_info = state.client_info
     Logger.debug "retrieve_and_cache_access_token(client_info)"
     Logger.debug "client_info: #{inspect client_info}"
     body = {:form, [grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer", assertion: client_info.jwt]}
     Logger.info "Getting bearer token"
     HTTPoison.post(state.auth_token_url, body)
     |> handle_access_token_response(state)
   end

   def handle_call(:get_jwt, _from, state) do
     state = check_initialized(state)
     {:reply, state.client_info.jwt, state}
   end

   def handle_call(:get_access_token, _from, state) do
     state = check_initialized(state)
     {:reply, state.access_token, state}
   end

   def handle_call(:force_refresh, _from, state) do
     state =
       state
       |> check_initialized()
       |> update_expired_jwt()
     {reply, state} = case retrieve_and_cache_access_token(state) do
       {:ok, state} -> {{:ok, state.access_token}, state}
       error -> {error, state}
     end
     {:reply, reply, state}
   end

   def handle_info(:refresh_token, state) do
     state =
       state
       |> check_initialized()
       |> update_expired_jwt()
     state = case retrieve_and_cache_access_token(state) do
       {:ok, state} -> state
       _ -> state
     end
     {:noreply, state}
   end

end
