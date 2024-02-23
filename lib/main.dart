import 'dart:convert';

import 'package:english_words/english_words.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;

Future<Favorite> createFavorite(WordPair wordPair) async{

  final response = await http.post(
      Uri.parse('http://127.0.0.1:5000/favorite/save'),
      headers: <String, String>{
        'Content-Type' : 'application/json; charset=UTF-8',
      },
      body: jsonEncode(<String, dynamic>{
        'first': wordPair.first,
        'second': wordPair.second,
      })
  );

  if (response.statusCode == 201){
    return Favorite.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  } else {
    throw Exception('Failed to post favorite');
  }

}

Future<Favorite> deleteFavorite(Favorite favorite) async {
  final response = await http.delete(
      Uri.parse('http://127.0.0.1:5000/favorite/delete/${favorite.id}')
  );

  if (response.statusCode == 200) {
    return Favorite.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  } else {
    throw Exception('Failed to delete favorite');
  }
}

class Favorite extends WordPair{
  final int id;

  Favorite(super.first, super.second, this.id);

  factory Favorite.fromJson(Map<String, dynamic> json){
    return switch (json) {
      {
      'id': int id,
      'first': String first,
      'second': String second,
      } => Favorite(first, second, id),
      _ => throw const FormatException('Failed To load favorite')
    };
  }
}

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => MyAppState(),
      child: MaterialApp(
        title: 'Namer App',
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepOrange),
        ),
        home: MyHomePage(),
      ),
    );
  }
}

class MyAppState extends ChangeNotifier {
  var current = WordPair.random();
  var history = <WordPair>[];
  GlobalKey? historyListKey;
  List<Favorite> _favorites = [];

  MyAppState() {
    fetchFavorites();
  }

  void getNext() {
    history.insert(0, current);
    var animatedList = historyListKey?.currentState as AnimatedListState?;
    animatedList?.insertItem(0);
    current = WordPair.random();
    notifyListeners();
  }

  Future<void> toggleFavorite ([WordPair? pair]) async {
    pair = pair ?? current;

    if (_favorites.contains(pair)) {
      Favorite remFav = await deleteFavorite(_favorites.firstWhere((favorite) => favorite == pair, orElse: () => Favorite('null', 'null', -1)));
      _favorites.remove(remFav);
    } else {
      Favorite newFav = await createFavorite(pair);
      _favorites.add(newFav);
    }
    notifyListeners();
  }

  Future<void> fetchFavorites() async {
    final response = await http.get(Uri.parse('http://127.0.0.1:5000/favorite/get'));

    final List<Map<String, dynamic>> dataList = jsonDecode(response.body);

    if (response.statusCode == 200){
      var favorites = <Favorite>[];
      for (var data in dataList){
        favorites.add(Favorite.fromJson(data));
      }
      _favorites = favorites;
    } else {
      throw Exception('Failed to load some json');
    }
  }

  Future<void> addAll(Function fetch) async {
    _favorites = await fetch();
    print(_favorites);
    notifyListeners();
  }

  Future<void> deleteSelectedFavorite(WordPair favorite) async {
    if(_favorites.contains(favorite)){
      Favorite remFav = await deleteFavorite(_favorites.firstWhere((element) => element == favorite));
      _favorites.remove(remFav);
    }
    notifyListeners();
  }
}

class MyHomePage extends StatefulWidget {
  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  var selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    Widget page;
    switch (selectedIndex) {
      case 0:
        page = GeneratorPage();
        break;
      case 1:
        page = FavoritePage();
        break;
      default:
        throw UnimplementedError('no widget for $selectedIndex');
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return Scaffold(
          body: Row(
            children: [
              SafeArea(
                child: NavigationRail(
                  extended: constraints.maxWidth >= 600,
                  destinations: [
                    NavigationRailDestination(
                      icon: Icon(Icons.home),
                      label: Text('Home'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.favorite),
                      label: Text('Favorites'),
                    ),
                  ],
                  selectedIndex: selectedIndex,
                  onDestinationSelected: (value) {
                    setState(() {
                      selectedIndex = value;
                    });
                  },
                ),
              ),
              Expanded(
                child: Container(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  child: page,
                ),
              ),
            ],
          ),
        );
      }
    );
  }
}

class GeneratorPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    var appState = context.watch<MyAppState>();
    var pair = appState.current;

    IconData icon;
    if (appState._favorites.contains(pair)) {
      icon = Icons.favorite;
    } else {
      icon = Icons.favorite_border;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            flex: 3,
            child: HistoryListView(),
          ),
          SizedBox(height: 10),
          BigCard(pair: pair),
          SizedBox(height: 10),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ElevatedButton.icon(
                onPressed: () {
                  appState.toggleFavorite();
                },
                icon: Icon(icon),
                label: Text('Like'),
              ),
              SizedBox(width: 10),
              ElevatedButton(
                onPressed: () {
                  appState.getNext();
                },
                child: Text('Next'),
              ),
            ],
          ),
          Spacer(flex: 2),
        ],
      ),
    );
  }
}

class BigCard extends StatelessWidget {
  const BigCard({
    Key? key,
    required this.pair,
  }) : super(key: key);

  final WordPair pair;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final style = theme.textTheme.displayMedium!.copyWith(
      color: theme.colorScheme.onPrimary,
    );

    return Card(
      color: theme.colorScheme.primary,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: AnimatedSize(
          duration: Duration(milliseconds: 200),

          child: MergeSemantics(
            child: Wrap(
              children: [
                Text(
                  pair.first,
                  style: style.copyWith(fontWeight: FontWeight.w200),
                ),
                Text(
                  pair.second,
                  style: style.copyWith(fontWeight: FontWeight.bold)
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class FavoritePage extends StatelessWidget{
  @override
  Widget build(BuildContext context){
    var appState = context.watch<MyAppState>();
    var favorites = appState._favorites;
    var theme = Theme.of(context);

    if (favorites.isEmpty){
      return Center(
        child: Text("No favorites yet."),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.all(30),
          child: Text("You have ${favorites.length} favorites:"),
        ),
        Expanded(
          child: GridView(
            gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 400,
              childAspectRatio: 400 / 80,
            ),
            children: <Widget>[
              for (var favorite in favorites)
                ListTile(
                  leading: IconButton(
                    onPressed: () {
                      appState.deleteSelectedFavorite(favorite);
                    },
                    icon: Icon(Icons.heart_broken, semanticLabel: "Delete"),
                    color: theme.colorScheme.primary,
                  ),
                  title: Text(
                    favorite.asLowerCase,
                    semanticsLabel: favorite.asPascalCase,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class HistoryListView extends StatefulWidget{
  const HistoryListView({Key? key}) : super(key: key);

  @override
  State<HistoryListView> createState() => _HistoryListViewState();
}

class _HistoryListViewState extends State<HistoryListView>{
  final _key = GlobalKey();

  static const Gradient _maskingGradient = LinearGradient(
    colors: [Colors.transparent, Colors.black],
    stops: [0.0, 0.5],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<MyAppState>();
    appState.historyListKey = _key;

    return ShaderMask(
      shaderCallback: (bounds) => _maskingGradient.createShader(bounds),
      blendMode: BlendMode.dstIn,
      child: AnimatedList(
        key: _key,
        reverse: true,
        padding: EdgeInsets.only(top: 100),
        initialItemCount: appState.history.length,
        itemBuilder: (context, index, animation) {
          final pair = appState.history[index];
          return SizeTransition(
            sizeFactor: animation,
            child: Center(
              child: TextButton.icon(
                onPressed: () {
                  appState.toggleFavorite(pair);
                },
                icon: appState._favorites.contains(pair)
                ? Icon(Icons.favorite, size: 12)
                : SizedBox(),
                label: Text(
                  pair.asLowerCase,
                  semanticsLabel: pair.asPascalCase,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
