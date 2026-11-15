extends Node
## Регистрация / вход через Supabase Auth (GoTrue REST API).

signal auth_result(ok: bool, message: String, logged_in: bool)

const CONFIG_PATH := "res://supabase_config.cfg"
const SESSION_PATH := "user://session.json"

var url := ""
var anon_key := ""
var access_token := ""
var refresh_token := ""
var user_id := ""
var email := ""


func _ready() -> void:
    var cfg := ConfigFile.new()
    if cfg.load(CONFIG_PATH) == OK:
        url = str(cfg.get_value("supabase", "url", "")).strip_edges().trim_suffix("/")
        anon_key = str(cfg.get_value("supabase", "anon_key", "")).strip_edges()


func is_configured() -> bool:
    return url.begins_with("http") and not url.contains("YOUR") and anon_key != "" and not anon_key.contains("YOUR")


func display_name() -> String:
    return email.split("@")[0] if email != "" else "Игрок"


func sign_up(mail: String, password: String) -> void:
    var r := await _request("/auth/v1/signup", {"email": mail, "password": password})
    if not r.ok:
        auth_result.emit(false, _error_text(r), false)
        return
    var data: Dictionary = r.data
    if data.has("access_token"):
        _apply_session(data)
        auth_result.emit(true, "Аккаунт создан!", true)
    else:
        auth_result.emit(true, "Аккаунт создан. Подтверди email по ссылке из письма, затем войди.", false)


func sign_in(mail: String, password: String) -> void:
    var r := await _request("/auth/v1/token?grant_type=password", {"email": mail, "password": password})
    if not r.ok:
        auth_result.emit(false, _error_text(r), false)
        return
    _apply_session(r.data)
    auth_result.emit(true, "Вход выполнен", true)


func try_restore() -> bool:
    if not is_configured() or not FileAccess.file_exists(SESSION_PATH):
        return false
    var f := FileAccess.open(SESSION_PATH, FileAccess.READ)
    var saved = JSON.parse_string(f.get_as_text())
    f.close()
    if not (saved is Dictionary) or str(saved.get("refresh_token", "")) == "":
        return false
    var r := await _request("/auth/v1/token?grant_type=refresh_token", {"refresh_token": saved["refresh_token"]})
    if not r.ok:
        return false
    _apply_session(r.data)
    return true


func sign_out() -> void:
    access_token = ""
    refresh_token = ""
    user_id = ""
    email = ""
    if FileAccess.file_exists(SESSION_PATH):
        DirAccess.remove_absolute(ProjectSettings.globalize_path(SESSION_PATH))


func _apply_session(data: Dictionary) -> void:
    access_token = str(data.get("access_token", ""))
    refresh_token = str(data.get("refresh_token", ""))
    var u: Dictionary = data.get("user", {})
    user_id = str(u.get("id", ""))
    email = str(u.get("email", ""))
    var f := FileAccess.open(SESSION_PATH, FileAccess.WRITE)
    if f:
        f.store_string(JSON.stringify({"refresh_token": refresh_token}))
        f.close()


func _error_text(r: Dictionary) -> String:
    var d: Dictionary = r.data if r.data is Dictionary else {}
    for key in ["msg", "error_description", "message", "error"]:
        if d.has(key):
            return str(d[key])
    return "Ошибка сети (код %d)" % int(r.code)


func _request(path: String, body: Dictionary) -> Dictionary:
    var http := HTTPRequest.new()
    http.timeout = 15.0
    add_child(http)
    var headers := PackedStringArray(["apikey: " + anon_key, "Content-Type: application/json"])
    var err := http.request(url + path, headers, HTTPClient.METHOD_POST, JSON.stringify(body))
    if err != OK:
        http.queue_free()
        return {"ok": false, "code": 0, "data": {}}
    var res = await http.request_completed
    http.queue_free()
    var text: String = (res[3] as PackedByteArray).get_string_from_utf8()
    var data = JSON.parse_string(text)
    if data == null:
        data = {}
    var ok: bool = res[0] == HTTPRequest.RESULT_SUCCESS and res[1] >= 200 and res[1] < 300
    return {"ok": ok, "code": res[1], "data": data}
