import 'package:flutter/material.dart';
import 'package:flutter_speech/flutter_speech.dart';
import 'package:http/http.dart' as http;
import 'dart:async';

void main() => runApp(MyApp());

class Language {
  final String name;
  final String code;

  const Language(this.name, this.code);
}

const languages = [
  Language('Pусский', 'ru_RU'),
  Language('English', 'en_US'),
];

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: Text('Управление машинкой'),
        ),
        body: CarControl(),
      ),
    );
  }
}

class CarControl extends StatefulWidget {
  @override
  _CarControlState createState() => _CarControlState();
}

class _CarControlState extends State<CarControl> {
  late SpeechRecognition _speech;

  bool _speechRecognitionAvailable = false;
  bool _isListening = false;

  String transcription = '';

  Language selectedLang = languages.first;

  List<String> commandQueue = [];
  Timer? commandTimer;

  bool isMovingForward = false;
  bool isMovingReverse = false;
  bool isMovingLeft = false;
  bool isMovingRight = false;

  double motorSpeed = 0.0; // Store the current motor speed.

  // Future<void> controlMotorSpeed(String command, [int? speed]) async {
  //   final Uri baseUri = Uri.parse("http://your_esp32_ip/");
  //   final Map<String, String> queryParameters = {
  //     'command': command,
  //   };

  //   if (speed != null) {
  //     queryParameters['speed'] = speed.toString();
  //   }

  //   final Uri uri = baseUri.replace(queryParameters: queryParameters);
  //   final response = await http.get(uri);

  //   if (response.statusCode == 200) {
  //     // Command successful
  //     if (command == "speed") {
  //       motorSpeed = speed!.toDouble();
  //     }
  //   } else {
  //     // Command failed
  //     print("Failed to send command: $command");
  //   }
  // }

  //double motorSpeed = 0.0; // Store the current motor speed.

  Future<void> sendCommandToESP32(String command) async {
    final esp32IpAddress = '192.168.199.63';
    final esp32Port = 80;

    final url =
        Uri.parse('http://$esp32IpAddress:$esp32Port/?command=$command');

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        print('Command sent successfully: $command');
      } else {
        print('Error sending command: ${response.statusCode}');
      }
    } catch (error) {
      print('Error executing HTTP request: $error');
    }
  }

  Future<void> controlMotorSpeed(int speed) async {
    // Use sendCommandToESP32 to control motor speed
    const command = "speed";
    await sendCommandToESP32("$command&speed=$speed");
    motorSpeed = speed.toDouble();
  }

  // sendCommandToESP32(String command) async {
  //   final esp32IpAddress = '192.168.199.63';
  //   final esp32Port = 80;

  //   final url =
  //       Uri.parse('http://$esp32IpAddress:$esp32Port/?command=$command');

  //   try {
  //     final response = await http.get(url);

  //     if (response.statusCode == 200) {
  //       print('Команда отправлена успешно: $command');
  //     } else {
  //       print('Ошибка при отправке команды: ${response.statusCode}');
  //     }
  //   } catch (error) {
  //     print('Произошла ошибка при выполнении HTTP-запроса: $error');
  //   }
  // }

  @override
  void initState() {
    super.initState();
    activateSpeechRecognizer();
  }

  void moveSquare() async {
    for (int i = 0; i < 7; i++) {
      // sendCommandToESP32('forward'); // Движение вперед
      // await Future.delayed(const Duration(seconds: 1)); // Пауза 1 секунда
      // sendCommandToESP32('stop'); // Остановка
      sendCommandToESP32('right'); // Поворот вправо
      await Future.delayed(
          const Duration(milliseconds: 150)); // Пауза 0.5 секунды
      sendCommandToESP32('stop'); // Остановка
      await Future.delayed(const Duration(milliseconds: 1000));
      sendCommandToESP32('forward'); // Движение вперед
      await Future.delayed(const Duration(milliseconds: 500));
      sendCommandToESP32('left'); // Остановка
      await Future.delayed(
          const Duration(milliseconds: 200)); // Задержка между движениями
      sendCommandToESP32('stop'); // Остановка
      await Future.delayed(const Duration(milliseconds: 1000));
      sendCommandToESP32('forward'); // Движение вперед
      await Future.delayed(const Duration(milliseconds: 300));
      sendCommandToESP32('stop');
      await Future.delayed(const Duration(milliseconds: 10000));
    }
    
  }

  void processVoiceCommand(String command) {
    if (command.contains("вперёд")) {
      sendCommandToESP32('forward');
    } else if (command.contains("назад")) {
      sendCommandToESP32('reverse');
    } else if (command.contains("лево")) {
      sendCommandToESP32('left');
    } else if (command.contains("право")) {
      sendCommandToESP32('right');
    } else if (command.contains("стоп")) {
      sendCommandToESP32('stop');
    } else if (command.contains("символ")) {
      moveSquare();
      sendCommandToESP32('stop');
    }
  }

  void activateSpeechRecognizer() {
    _speech = SpeechRecognition();
    _speech.setAvailabilityHandler(onSpeechAvailability);
    _speech.setRecognitionStartedHandler(onRecognitionStarted);
    _speech.setRecognitionResultHandler(onRecognitionResult);
    _speech.setRecognitionCompleteHandler(onRecognitionComplete);
    _speech.setErrorHandler(errorHandler);
    _speech.activate('ru_RU').then((res) {
      setState(() => _speechRecognitionAvailable = res);
    });
  }

  void addToCommandQueue(String command) {
    commandQueue.add(command);

    if (commandQueue.length == 1) {
      executeNextCommand();
    }
  }

  void executeNextCommand() {
    if (commandQueue.isNotEmpty) {
      final command = commandQueue.removeAt(0);
      setState(() {
        transcription = command;
      });

      if (commandQueue.isNotEmpty) {
        commandTimer = Timer(const Duration(seconds: 1), executeNextCommand);
      }
    }
  }

  void errorHandler() => activateSpeechRecognizer();

  void start() => _speech.activate(selectedLang.code).then((_) {
        return _speech.listen().then((result) {
          setState(() {
            processVoiceCommand(transcription);
            _isListening = result;
          });
        });
      });

  void cancel() =>
      _speech.cancel().then((_) => setState(() => _isListening = false));

  void stop() => _speech.stop().then((_) {
        setState(() {
          _isListening = false;
          processVoiceCommand;
        });
      });

  void onCurrentLocale(String locale) {
    setState(
        () => selectedLang = languages.firstWhere((l) => l.code == locale));
  }

  void onSpeechAvailability(bool result) =>
      setState(() => _speechRecognitionAvailable = result);

  void onRecognitionStarted() {
    setState(() => _isListening = true);
  }

  void onRecognitionResult(String text) {
    addToCommandQueue(text);
  }

  void onRecognitionComplete(String text) {
    setState(() {
      _isListening = false;
      processVoiceCommand(transcription);
      isMovingForward = false;
      isMovingReverse = false;
      isMovingLeft = false;
      isMovingRight = false;
    });
  }

  void _startMovingForward() {
    setState(() {
      isMovingForward = true;
      sendCommandToESP32('forward');
    });
  }

  void _startMovingLeft() {
    setState(() {
      isMovingLeft = true;
      sendCommandToESP32('left');
    });
  }

  void _startMovingRight() {
    setState(() {
      isMovingRight = true;
      sendCommandToESP32('right');
    });
  }

  void _startMovingReverse() {
    setState(() {
      isMovingReverse = true;
      sendCommandToESP32('reverse');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Container(
            height: 300,
            child: Column(
              children: [
                GestureDetector(
                  onTapDown: (details) {
                    _startMovingForward();
                  },
                  onTapUp: (details) {
                    setState(() {
                      isMovingForward = false;
                      sendCommandToESP32('stop');
                    });
                  },
                  child: Container(
                    width: 70,
                    height: 70,
                    color: isMovingForward ? Colors.green : Colors.red,
                    child: Center(
                      child: Text(isMovingForward ? 'Движение' : 'Вперед'),
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    GestureDetector(
                      onTapDown: (details) {
                        _startMovingLeft();
                      },
                      onTapUp: (details) {
                        setState(() {
                          isMovingLeft = false;
                          sendCommandToESP32('stop');
                        });
                      },
                      child: Container(
                        width: 70,
                        height: 70,
                        color: isMovingLeft ? Colors.green : Colors.red,
                        child: Center(
                          child: Text(isMovingLeft ? 'Движение' : 'Лево'),
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTapDown: (details) {
                        _startMovingRight();
                      },
                      onTapUp: (details) {
                        setState(() {
                          isMovingRight = false;
                          sendCommandToESP32('stop');
                        });
                      },
                      child: Container(
                        width: 70,
                        height: 70,
                        color: isMovingRight ? Colors.green : Colors.red,
                        child: Center(
                          child: Text(isMovingRight ? 'Движение' : 'Право'),
                        ),
                      ),
                    ),
                  ],
                ),
                GestureDetector(
                  onTapDown: (details) {
                    _startMovingReverse();
                  },
                  onTapUp: (details) {
                    setState(() {
                      isMovingReverse = false;
                      sendCommandToESP32('stop');
                    });
                  },
                  child: Container(
                    width: 70,
                    height: 70,
                    color: isMovingReverse ? Colors.green : Colors.red,
                    child: Center(
                      child: Text(isMovingReverse ? 'Движение' : 'Назад'),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Slider(
          //   value: motorSpeed,
          //   min: 0,
          //   max: 255, // Adjust this according to your motor's PWM range.
          //   onChanged: (value) {
          //     controlMotorSpeed(value.toInt());
          //   },
          // ),
          Container(
              height: 150,
              width: 200,
              padding: const EdgeInsets.all(8.0),
              color: Colors.grey.shade200,
              child: Text(transcription)),
          _buildButton(
            onPressed: _speechRecognitionAvailable && !_isListening
                ? () {
                    start();
                  }
                : null,
            label:
                _isListening ? 'Listening...' : 'Listen (${selectedLang.code})',
          ),
          _buildButton(
            onPressed: _isListening ? () => cancel() : null,
            label: 'Cancel',
          ),
          _buildButton(
            onPressed: _isListening ? () => stop() : null,
            label: 'Stop',
          ),
        ],
      ),
    );
  }

  Widget _buildButton({required String label, VoidCallback? onPressed}) {
    if (onPressed == null) {
      return Padding(
        padding: EdgeInsets.all(7.0),
        child: ElevatedButton(
          onPressed: null,
          child: Text(
            label,
            style: const TextStyle(color: Colors.white),
          ),
        ),
      );
    }

    return Padding(
        padding: EdgeInsets.all(12.0),
        child: ElevatedButton(
          onPressed: _isListening ? null : onPressed,
          child: Text(
            label,
            style: const TextStyle(color: Colors.white),
          ),
        ));
  }
}
