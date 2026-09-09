extends Control

const MQTTTestSuite = preload("res://tests/mqtt_test_suite.gd")
const PublicBrokerCheck = preload("res://tests/public_broker_check.gd")

@onready var break_on_failure: CheckBox = %BreakOnFailure
@onready var summary_label: Label = %Summary
@onready var results: RichTextLabel = %Results


func _ready() -> void:
	%RunTests.pressed.connect(run_tests)
	%RunPublicTests.pressed.connect(run_public_tests)
	run_tests()


func run_tests() -> void:
	%RunTests.disabled = true
	results.clear()
	summary_label.text = "Running…"
	var suite := MQTTTestSuite.new()
	suite.break_on_failure = break_on_failure.button_pressed
	suite.test_started.connect(_on_test_started)
	suite.test_finished.connect(_on_test_finished)
	var test_results := suite.run_all()
	var failure_count := 0
	for result in test_results:
		if not result.passed:
			failure_count += 1
	summary_label.text = "%d passed, %d failed" % [test_results.size() - failure_count, failure_count]
	%RunTests.disabled = false


func _on_test_started(test_name: String) -> void:
	results.append_text("[color=gray]RUN  %s[/color]\n" % test_name)


func _on_test_finished(result: Dictionary) -> void:
	if result.passed:
		results.append_text("[color=green]PASS %s[/color]  %.2f ms\n" % [result.name, result.elapsed_usec / 1000.0])
	else:
		results.append_text("[color=red]FAIL %s[/color]\n" % result.name)
		for failure in result.failures:
			results.append_text("      %s\n" % failure)


func run_public_tests() -> void:
	%RunPublicTests.disabled = true
	results.append_text("\n[b]Public broker checks (network-dependent)[/b]\n")
	for broker_url in ["tcp://broker.hivemq.com:1883", "tcp://test.mosquitto.org:1883"]:
		var check := PublicBrokerCheck.new()
		add_child(check)
		check.log_line.connect(func(line): results.append_text("      %s\n" % line))
		var result: Dictionary = await check.check(broker_url)
		var label := "PASS" if result.passed else "UNAVAILABLE"
		var color := "green" if result.passed else "orange"
		results.append_text("[color=%s]%s %s[/color] — %s\n" % [color, label, result.broker_url, result.detail])
		check.queue_free()
	%RunPublicTests.disabled = false
