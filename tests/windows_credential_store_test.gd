extends SceneTree

const WindowsCredentialStoreScript := preload(
	"res://src/platform/windows/windows_credential_store.gd"
)

var _failed := false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if OS.get_name() != "Windows":
		print("Windows credential store self-test skipped.")
		quit(0)
		return

	var store = WindowsCredentialStoreScript.new()
	root.add_child(store)
	var target := (
		"DesktopPet.Test."
		+ Crypto.new().generate_random_bytes(16).hex_encode()
	)
	var test_secret := (
		"refresh-token-test-"
		+ Crypto.new().generate_random_bytes(16).hex_encode()
	)

	var write_result: Array = []
	store.write_completed.connect(
		func(success: bool, error: String) -> void:
			write_result.append([success, error])
	)
	_expect(
		store.write_secret(target, test_secret),
		"credential write helper must start"
	)
	await _wait_for_result(write_result)
	_expect(
		not write_result.is_empty()
		and bool(write_result[0][0]),
		"Credential Manager must accept the temporary test secret"
	)

	var read_result: Array = []
	store.read_completed.connect(
		func(secret: String, success: bool, error: String) -> void:
			read_result.append([secret, success, error])
	)
	_expect(
		store.read_secret(target),
		"credential read helper must start"
	)
	await _wait_for_result(read_result)
	_expect(
		not read_result.is_empty()
		and bool(read_result[0][1])
		and str(read_result[0][0]) == test_secret,
		"Credential Manager must return the exact temporary test secret"
	)

	var delete_result: Array = []
	store.delete_completed.connect(
		func(success: bool, error: String) -> void:
			delete_result.append([success, error])
	)
	_expect(
		store.delete_secret(target),
		"credential delete helper must start"
	)
	await _wait_for_result(delete_result)
	_expect(
		not delete_result.is_empty()
		and bool(delete_result[0][0]),
		"Credential Manager must remove the temporary test secret"
	)

	var empty_result: Array = []
	store.read_completed.connect(
		func(secret: String, success: bool, error: String) -> void:
			empty_result.append([secret, success, error])
	)
	_expect(
		store.read_secret(target),
		"credential verification read helper must start"
	)
	await _wait_for_result(empty_result)
	_expect(
		not empty_result.is_empty()
		and bool(empty_result[0][1])
		and str(empty_result[0][0]).is_empty(),
		"deleted test credentials must not remain in Credential Manager"
	)

	if _failed:
		quit(1)
		return
	print("Windows credential store self-test passed.")
	quit(0)


func _wait_for_result(result: Array) -> void:
	for _frame in 300:
		if not result.is_empty():
			return
		await process_frame


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("Windows credential store self-test failed: %s" % message)
