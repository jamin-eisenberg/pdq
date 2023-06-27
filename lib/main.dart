import 'dart:core';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PDQ',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class Letter {
  static const int aVal = 65; // ascii capital A
  static const List<int> freqs = [
    4, // A
    4, // B
    3, // C
    4, // D
    4, // E
    3, // F
    4, // G
    4, // H
    4, // I
    1, // J
    1, // K
    4, // L
    4, // M
    4, // N
    4, // O
    4, // P
    1, // Q
    4, // R
    4, // S
    4, // T
    4, // U
    1, // V
    1, // W
    1, // X
    1, // Y
    1, // Z
  ];

  late int value;

  Letter(int value) {
    if (value >= 0 && value < 26) {
      this.value = value;
    } else {
      throw Exception("Letter must have a value from 0 to 25");
    }
  }

  Letter.fromString(s) : value = s.codeUnitAt(0) - aVal;

  Letter.random() : value = Random().nextInt(26);

  @override
  String toString() {
    return String.fromCharCode(value + aVal);
  }
}

abstract class Action {}

class Skip implements Action {}

class Win implements Action {
  int player;

  Win(this.player);
}

class _MyHomePageState extends State<MyHomePage> {
  Set<String> wordlist = {};
  List<Letter> _deck = [];
  List<Letter> _discard = [];
  bool _viewingAnswers = false;
  List<String> _answers = [];

  List<Action> _actions = [];

  Future<void> loadWordlist() async {
    wordlist = (await DefaultAssetBundle.of(context)
            .loadString('assets/english_wordlist.txt', cache: true))
        .split("\n")
        .map((e) => e.toUpperCase())
        .toSet();
  }

  void _newLetters() {
    if (_deck.isNotEmpty) {
      setState(() {
        _discard.addAll(_deck.getRange(0, 3));
        _deck.removeRange(0, 3);
        _viewingAnswers = false;
        if (_deck.isNotEmpty) {
          _answers = _getSolutions((_deck[0], _deck[1], _deck[2]));
        }
      });
    }
  }

  void _start() {
    loadWordlist().then((_) => setState(() {
          _deck = _createDeck();
          _discard = [];
          _actions = [];
          _answers = _getSolutions((_deck[0], _deck[1], _deck[2]));
        }));
  }

  List<Letter> _createDeck() {
    List<Letter> deck = [];
    for (var (i, freq) in Letter.freqs.indexed) {
      deck.addAll(List.generate(freq, (_) => Letter(i)));
    }
    deck.shuffle();
    return deck;
  }

  List<String> _getSolutions((Letter, Letter, Letter) letters) {
    var regexForward = RegExp(
        '${letters.$1.toString() == "X" ? "E?" : ""}${letters.$1.toString()}.*${letters.$2.toString()}.*${letters.$3.toString()}.*');
    var regexBackward = RegExp(
        '${letters.$1.toString() == "X" ? "E?" : ""}${letters.$3.toString()}.*${letters.$2.toString()}.*${letters.$1.toString()}.*');

    return wordlist
        .where((word) => regexForward.matchAsPrefix(word) != null)
        .toSet()
        .union(wordlist
            .where((word) => regexBackward.matchAsPrefix(word) != null)
            .toSet())
        .toList();
  }

  List<T> interleave<T>(List<T> ls, T item) {
    List<T> ans = [];
    for (int i = 0; i < ls.length - 1; i++) {
      ans.add(ls[i]);
      ans.add(item);
    }
    ans.add(ls[ls.length - 1]);
    return ans;
  }

  @override
  Widget build(BuildContext context) {
    var scoreStyle = const TextStyle(fontSize: 50);

    getPlayerScore(player) {
      var skipsSinceLastWin = 0;
      var score = 0;
      for (var action in _actions) {
        if (action is Skip) {
          skipsSinceLastWin++;
        } else if (action is Win && action.player == player) {
          score += skipsSinceLastWin + 1;
        }
        if (action is Win) {
          skipsSinceLastWin = 0;
        }
      }
      return score;
    }

    letterStyle(int size) => TextStyle(
            fontSize: size.toDouble(),
            fontWeight: FontWeight.w900,
            letterSpacing: 10,
            color: const Color.fromARGB(255, 103, 84, 200),
            shadows: [
              for (var v in List.generate(5, (i) => i + 1))
                Shadow(
                    color: Colors.deepPurple.shade900,
                    offset: Offset((-v).toDouble(), v.toDouble()))
            ]);

    scoreboard(player) => Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              iconSize: scoreStyle.fontSize! - 10,
              onPressed: () => {
                if (_discard.isEmpty)
                  {
                    _showMessage(context,
                        "You can't go back on the first round of letters.")
                  }
                else if ((_actions.last is Win &&
                        (_actions.last as Win).player != player) &&
                    _actions.last is! Skip)
                  {
                    _showMessage(
                        context, "Only the player who last scored can go back.")
                  }
                else
                  {
                    setState(() {
                      _actions.removeLast();
                      _viewingAnswers = false;
                      _deck.insertAll(
                          0,
                          _discard.getRange(
                              _discard.length - 3, _discard.length));
                      _discard.removeRange(
                          _discard.length - 3, _discard.length);
                      _answers = _getSolutions((_deck[0], _deck[1], _deck[2]));
                    }),
                  }
              },
              // TODO: animate laying down?, more than 2 player
              icon: const Icon(Icons.remove),
            ),
            const SizedBox(width: 7),
            Text('${getPlayerScore(player)}', style: scoreStyle),
            const SizedBox(width: 7),
            IconButton(
                iconSize: scoreStyle.fontSize! - 10,
                onPressed: () => {
                      if (_deck.isNotEmpty)
                        {
                          setState(() {
                            _actions.add(Win(player));
                            _newLetters();
                          })
                        }
                      else
                        {
                          _showMessage(context,
                              "You need to start a new game to get more letters.")
                        }
                    },
                icon: const Icon(Icons.add)),
          ],
        );

    List<Widget> letterText(Letter letter) {
      if (letter.toString() != "X") {
        return [
          Text(
            letter.toString(),
            style: letterStyle(100),
          )
        ];
      } else {
        return [
          Text(
            "(E)",
            style: letterStyle(30).copyWith(
              letterSpacing: 0,
              shadows: [
                Shadow(
                    color: Colors.deepPurple.shade900,
                    offset: const Offset(-1, 1))
              ],
            ),
          ),
          Text("X", style: letterStyle(100))
        ];
      }
    }

    var letters = _deck.isEmpty
        ? const Text('')
        : Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children:
                interleave(_deck.getRange(0, 3).map(letterText).toList(), [
              const SizedBox(
                width: 20,
              ),
            ]).expand((e) => e).toList(),
          );

    var startButton = ElevatedButton(
      onPressed: _start,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            Text(
              "NEW",
              textAlign: TextAlign.center,
              style: letterStyle(70),
            ),
            RotatedBox(
                quarterTurns: 2,
                child: Text(
                  "GAME",
                  textAlign: TextAlign.center,
                  style: letterStyle(70),
                ))
          ],
        ),
      ),
    );

    return SafeArea(
      child: Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              RotatedBox(quarterTurns: 2, child: scoreboard(1)),
              const Spacer(),
              if (_deck.isNotEmpty) ...[
                letters,
                RotatedBox(
                  quarterTurns: 2,
                  child: letters,
                ),
                if (!_viewingAnswers)
                  TextButton(
                      onPressed: () => setState(() {
                            _viewingAnswers = true;
                          }),
                      child: const Text("View Solutions"))
                else if (_answers.isNotEmpty)
                  SizedBox(
                    height: 200,
                    child: ListView.builder(
                      primary: false,
                      itemCount: _answers.length,
                      itemExtent: 25,
                      itemBuilder: (context, index) => ListTile(
                        title:
                            Text(textAlign: TextAlign.center, _answers[index]),
                        dense: true,
                        visualDensity: const VisualDensity(vertical: -3),
                      ),
                    ),
                  )
                else
                  const Text('No solutions found!')
              ] else
                startButton,
              const Spacer(),
              scoreboard(0),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => {
            setState(() {
              if (_deck.isNotEmpty) {
                _actions.add(Skip());
                _newLetters();
              } else {
                _showMessage(context, "Nothing to skip.");
              }
            })
          },
          tooltip: 'Skip',
          child: const Icon(Icons.skip_next),
        ),
      ),
    );
  }

  void _showMessage(BuildContext context, String message) {
    final scaffold = ScaffoldMessenger.of(context);
    scaffold.showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }
}
