import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:english_words/english_words.dart';
import 'package:flutter/widgets.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:snapping_sheet/snapping_sheet.dart';
import 'package:circular_profile_avatar/circular_profile_avatar.dart';
import 'package:firebase_storage/firebase_storage.dart' as firebaseStorage;
import 'package:file_picker/file_picker.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';


void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(App());
}

class App extends StatelessWidget {
  final Future<FirebaseApp> _initialization = Firebase.initializeApp();
  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
        future: _initialization,
        builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Scaffold(
            body: Center(
                child: Text(snapshot.error.toString(),
                    textDirection: TextDirection.ltr)));
      }
      if (snapshot.connectionState == ConnectionState.done) {return MyApp();
      }
      return Center(child: CircularProgressIndicator());
        },
    );
  }
}


class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<UserRepository>(
        create: (_) => UserRepository.instance(),
        child: Consumer<UserRepository>(
          builder: (context, UserRepository user, _) {
            return MaterialApp(
              title: 'Startup Name Generator',
              theme: ThemeData(
                primaryColor: Colors.red[900],
              ),
              home: RandomWords(),
            );
          }
        ),
    );
  }
}

class RandomWords extends StatefulWidget {
  @override
  _RandomWordsState createState() => _RandomWordsState();
}

class _RandomWordsState extends State<RandomWords> {
  final _formKey = GlobalKey<FormState>();
  final _formKey2 = GlobalKey<FormState>();
  final _key = GlobalKey<ScaffoldState>();
  String _email;
  String _password;
  String _confirmPassword;
  SnappingSheetController _control = SnappingSheetController();

  final List<WordPair> _suggestions = <WordPair>[];
  final _saved = Set<WordPair>();
  final TextStyle _biggerFont = const TextStyle(fontSize: 18);

  void _pushSaved() {
    final user = Provider.of<UserRepository>(context, listen: false);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) {
          return Scaffold(
            appBar: AppBar(
              title: Text('Saved Suggestions'),
            ),
            body: StatefulBuilder(builder: (context, innerState) =>  ListView(
                children: ListTile.divideTiles(
                  context: context,
                  tiles: _saved.map(
                        (WordPair pair) {
                        return ListTile(
                          title: Text(
                            pair.asPascalCase,
                            style: _biggerFont,
                          ),
                          trailing: IconButton(
                            icon: Icon(
                              Icons.delete_outline_rounded,
                              color: Colors.red[900],
                            ),
                            onPressed: () {
                              innerState(() {
                                setState(() {
                                  _saved.remove(pair);
                                  if(user.status == Status.Authenticated) {
                                    user._removeUserFavorite(pair);
                                  }
                                });
                              },);
                            },
                            // onPressed: ,
                          ),
                          );
                      },
                    ),
                  ).toList()
            )
            ),
          );
        },
      ),
    );
  }

  void _loginPage() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) {
          final user = Provider.of<UserRepository>(context);
          return Scaffold(
            key: _key,
            appBar: AppBar(
              title: Text('Login'),
          ),
            body: Builder(builder: (context) =>   Center(
              child: Form(
                key: _formKey,
                child:
                  Column(
                    children: <Widget>[
                      SizedBox(height: 50),
                      Flexible(
                        child: Text(
                          'Welcome to Startup Names Generator, please log in below',
                          style: TextStyle(
                            fontWeight: FontWeight.normal,
                            fontSize: 15.0,
                          ),
                        ),
                      ),
                      SizedBox(height: 10),
                      Padding(
                        padding: EdgeInsets.all(10),
                        child: TextFormField(
                          onChanged:(value) => _email = value,
                          //onSaved: (value) => _email = value,
                          validator: (value) =>
                          (value.isEmpty) ? "Please Enter Email" : null,
                          textAlignVertical: TextAlignVertical.center,
                          textAlign: TextAlign.left,
                          maxLines: 1,
                          decoration: InputDecoration(
                            labelText: 'Email',
                            contentPadding: EdgeInsets.all(10) ,
                          ),
                        ),
                      ),
                      SizedBox(height: 5),
                      Padding(
                        padding: EdgeInsets.all(5.0),
                        child: TextFormField(
                          onChanged:(value) => _password = value,
                          //onSaved: (value) => _password = value,
                          validator: (value) =>
                            (value.isEmpty) ? "Please Enter Password" : null,
                          obscureText: true,
                          keyboardType: TextInputType.visiblePassword,
                          textAlignVertical: TextAlignVertical.center,
                          textAlign: TextAlign.left,
                          maxLines: 1,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            contentPadding: EdgeInsets.all(10) ,
                          ),
                        ),
                      ),
                      SizedBox(height: 20),
                      user.status == Status.Authenticating ?
                      Center(child: CircularProgressIndicator(
                        backgroundColor: Colors.grey[600],
                        valueColor: new AlwaysStoppedAnimation<Color>(Colors.red[900]),
                      ))
                        :Flexible(
                            child: RaisedButton(
                              child: Text('Log in'),
                              color: Colors.red[900],
                              textColor: Colors.white,
                              onPressed: () async {
                                if (_formKey.currentState.validate()) {
                                if (!await user.signIn(_email, _password)) {
                                  final snackBar = SnackBar(
                                    content: Text(
                                      'There was an error logging into the app'),
                                  );
                                  //_key.currentState.showSnackBar(snackBar);
                                  Scaffold.of(context).showSnackBar(snackBar);
                                }else {
                                  Navigator.popUntil(context, ModalRoute.withName('/'));
                                  await user._addUserDoc();
                                  List favoritesToSave = _saved.toList();
                                  for(var i = 0; i <favoritesToSave.length; i++){
                                    user._updateUserFavorites(favoritesToSave[i]);
                                  }
                                  user._loadFromFireBase(_saved,_suggestions);
                                  await user._loadAvatar();
                                }}
                              },
                              padding: EdgeInsets.fromLTRB(150, 10, 150, 10),
                              shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(28.0),
                              side: BorderSide(color: Colors.red[900]),
                            ),
                          ),
                      ),
                      SizedBox(height: 10),
                      RaisedButton(
                            child: Text('New user? Click to sign up'),
                            color: Colors.teal[700],
                            textColor: Colors.white,
                            onPressed: () {
                              showModalBottomSheet(
                                  isScrollControlled: true,
                                  context: context,
                                  builder: (context) {

                                    return Form(
                                      key: _formKey2,
                                      child: Padding(
                                        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
                                        child: Container(
                                          height: MediaQuery.of(context).size.height  * 0.3,
                                          child: Center(
                                            child: Column(
                                              children:[
                                                Padding(
                                                  padding: const EdgeInsets.all(10),
                                                  child: Container(
                                                    child: Text(
                                                      'Please confirm your password below:',
                                                      style: TextStyle(
                                                        fontWeight: FontWeight.normal,
                                                        fontSize: 15.0,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                const Divider(
                                                  color: Colors.grey,
                                                   indent: 20,
                                                  endIndent: 20,
                                                ),
                                                Padding(
                                                  padding: EdgeInsets.all(10.0),
                                                  child: TextFormField(
                                                    onChanged:(value) => _confirmPassword = value,
                                                    //onSaved: (value) => _confirmPassword = value,
                                                    validator: (value) =>
                                                      (value != _password) ? "Passwords must match" : null,
                                                    // validator: (value) =>
                                                    //  (value.isEmpty) ? "Please Enter Password" : null,
                                                    obscureText: true,
                                                    keyboardType: TextInputType.visiblePassword,
                                                    textAlignVertical: TextAlignVertical.center,
                                                    textAlign: TextAlign.left,
                                                    maxLines: 1,
                                                    decoration: InputDecoration(
                                                      labelText: 'Password',
                                                      contentPadding: EdgeInsets.all(10) ,
                                                    ),
                                                  ),
                                                ),
                                                RaisedButton(
                                                  child: Text('Confirm'),
                                                  color: Colors.teal[700],
                                                  textColor: Colors.white,
                                                  onPressed: () async {
                                                    if(_formKey.currentState.validate()) {
                                                      if(_formKey2.currentState.validate()) {
                                                        try{
                                                          await FirebaseAuth.instance.createUserWithEmailAndPassword(email: _email, password: _password);
                                                          }
                                                          catch(e){
                                                          final snackBar = SnackBar(
                                                            content: Text(
                                                                'Password should be at least 6 characters'),
                                                          );
                                                          _key.currentState.showSnackBar(snackBar);
                                                          }
                                                        if(!await user.signIn(_email, _password)) {
                                                          final snackBar = SnackBar(
                                                            content: Text(
                                                                'There was an error logging into the app'),
                                                          );
                                                          _key.currentState.showSnackBar(snackBar);
                                                          // Scaffold.of(context).showSnackBar(snackBar);
                                                        }
                                                        else {
                                                          Navigator.popUntil(context, ModalRoute.withName('/'));
                                                          await user._addUser();
                                                        }
                                                      }
                                                    }
                                                  },
                                                ),
                                              ]
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  }
                              );
                            },
                            padding: EdgeInsets.fromLTRB(86, 10, 86, 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(28.0),
                              side: BorderSide(color: Colors.teal[700]),
                            ),
                          )
                    ]
                ),
              ),
            ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<UserRepository>(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('Startup Name Generator'),
        actions: [
          IconButton(icon: Icon(Icons.list), onPressed: _pushSaved),
          user.status == Status.Authenticated ?
          IconButton(icon: Icon(Icons.logout), onPressed: (){
            user.signOut();
            _saved.clear();
          })
          : IconButton(icon: Icon(Icons.login), onPressed: _loginPage),
        ],
      ),
      body: user.status != Status.Authenticated ?
      _buildSuggestions()
      : SnappingSheet(
        snappingSheetController: _control,
        sheetBelow: SnappingSheetContent(
            child: ListView(
              children: [
                Container(
                  color: Colors.white,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(15),
                        child: CircularProfileAvatar(
                          null,
                          child: Center(
                            child:
                                user._avatar == null ?
                              Icon(
                                Icons.person,
                                size: 50,
                              )
                                : Image.network(user._avatar, fit: BoxFit.fitHeight),
                          ),
                          borderColor: Colors.transparent,
                          borderWidth: 2,
                          elevation: 2,
                          radius: 40,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(0,10,0,0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(' $_email',
                              style: TextStyle(
                                fontWeight: FontWeight.normal,
                                fontSize: 20.0,
                              ),
                            ),
                            ButtonBar(
                              children: [
                            Builder(
                              builder: (context) => RaisedButton(
                                child: Text('Change avatar'),
                                color: Colors.teal[700],
                                textColor: Colors.white,
                                onPressed: () async {
                                  FilePickerResult res = await FilePicker.platform.pickFiles();
                                  if(res != null){
                                    File file = File(res.files.single.path);
                                    firebaseStorage.Reference ref = firebaseStorage.FirebaseStorage.instance.ref().child(user.user.uid.toString());
                                    await ref.putFile(file);
                                    await user._loadAvatar();
                                  }
                                  else{
                                    final snackBar = SnackBar(
                                      content: Text('No image selected'),
                                    );
                                    Scaffold.of(context).showSnackBar(snackBar);
                                  }
                                },
                                padding: EdgeInsets.fromLTRB(10, 7, 10, 7),
                              ),
                            ),
                              ],
                            ),
                          ],
                        ),
                      )
                    ],
                  ),
                ),
              ],
            ),
        heightBehavior: SnappingSheetHeight.fit()),
        sheetAbove: SnappingSheetContent(child: _buildSuggestions()),
        snapPositions: [
          SnapPosition(
              positionPixel: 0,
              snappingCurve: Curves.elasticInOut,
              snappingDuration: Duration(milliseconds: 20)
          ),
          SnapPosition(
              positionPixel: 130,
              snappingCurve: Curves.ease,
              snappingDuration: Duration(milliseconds: 20)
          ),
        ],
        grabbingHeight: 50,
        grabbing: Container(
          child:Material(
            child:InkWell(
              child: Padding(
                padding: EdgeInsets.all(15),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      child: Text('Welcome back, $_email',
                        style: TextStyle(
                          fontWeight: FontWeight.normal,
                          fontSize: 15.0,
                        ),
                      ),
                    ),
                    Container(
                      child: Icon(Icons.keyboard_arrow_up)
                    )
                  ]
                ),
              ),
              onTap: (){
                if(_control.currentSnapPosition.positionPixel == 0){
                  _control.snapToPosition(_control.snapPositions[1]);
                }else{
                _control.snapToPosition(_control.snapPositions[0]);
                }
              },
            ),
            color: Colors.grey[500],
          ),
        ),
      ),
    );
  }

  Widget _buildRow(WordPair pair) {
    final user = Provider.of<UserRepository>(context);
    final alreadySaved = _saved.contains(pair);
    return ListTile(
      title: Text(
        pair.asPascalCase,
        style: _biggerFont,
      ),
      trailing: Icon(
        alreadySaved ? Icons.favorite : Icons.favorite_border,
        color: alreadySaved ? Colors.red[900] : null,
      ),
      onTap: () {
        setState(() {
          if (alreadySaved) {
            _saved.remove(pair);
            if(user.status == Status.Authenticated) {
              user._removeUserFavorite(pair);
            }
          } else {
            _saved.add(pair);
             if(user.status == Status.Authenticated) {
              user._updateUserFavorites(pair);
            }
          }
        });
      },
    );
  }

  Widget _buildSuggestions() {
    return ListView.builder(
        padding: const EdgeInsets.all(16),
        // The itemBuilder callback is called once per suggested
        // word pairing, and places each suggestion into a ListTile
        // row. For even rows, the function adds a ListTile row for
        // the word pairing. For odd rows, the function adds a
        // Divider widget to visually separate the entries. Note that
        // the divider may be difficult to see on smaller devices.
        itemBuilder: (BuildContext _context, int i) {
          // Add a one-pixel-high divider widget before each row
          // in the ListView.
          if (i.isOdd) {
            return Divider();
          }

          // The syntax "i ~/ 2" divides i by 2 and returns an
          // integer result.
          // For example: 1, 2, 3, 4, 5 becomes 0, 1, 1, 2, 2.
          // This calculates the actual number of word pairings
          // in the ListView,minus the divider widgets.
          final int index = i ~/ 2;
          // If you've reached the end of the available word
          // pairings...
          if (index >= _suggestions.length) {
            // ...then generate 10 more and add them to the
            // suggestions list.
            _suggestions.addAll(generateWordPairs().take(10));
          }
          return _buildRow(_suggestions[index]);
        }
    );
  }
}


enum Status { Uninitialized, Authenticated, Authenticating, Unauthenticated }

class UserRepository with ChangeNotifier {
  FirebaseAuth  _auth;
  User _user;
  Status _status = Status.Uninitialized;
  String _avatar;

  UserRepository.instance() : _auth = FirebaseAuth.instance {
    _auth.authStateChanges().listen(_authStateChanges);
  }

  Status get status => _status;
  User get user => _user;

  Future<bool> signIn(String email, String password) async {
    try {
      _status = Status.Authenticating;
      notifyListeners();
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      _status = Status.Authenticated;
      notifyListeners();
      return true;
    } catch (e) {
      _status = Status.Unauthenticated;
      notifyListeners();
      return false;
    }
  }

  Future signOut() async {
    _auth.signOut();
    _status = Status.Unauthenticated;
    _avatar = null;
    notifyListeners();
    return Future.delayed(Duration.zero);
  }

  Future<void> _authStateChanges(User firebaseUser) async {
    if (firebaseUser == null) {
      _status = Status.Unauthenticated;
    } else {
      _user = firebaseUser;
      _status = Status.Authenticated;
    }
    notifyListeners();
  }

  void _updateUserFavorites(WordPair pair) async {
    final User user = _auth.currentUser;
    final userId = user.uid;

    await FirebaseFirestore.instance.collection('users').doc(userId.toString()).update({'favorites': FieldValue.arrayUnion([pair.asPascalCase])});
  }

  void _removeUserFavorite(WordPair pair){
    final User user = _auth.currentUser;
    final userId = user.uid;
    FirebaseFirestore.instance.collection('users').doc(userId.toString()).update({'favorites': FieldValue.arrayRemove([pair.asPascalCase])});
  }

  WordPair _alreadySaved(String wordToCheck, List pairs){
    for(int i = 0; i < pairs.length; i++){
      if(pairs[i] != null && pairs[i].asPascalCase == wordToCheck){
        return pairs[i];
      }
    }
    return null;
  }

  void _loadFromFireBase(Set savedSet, List pairs) async {
    final User user = _auth.currentUser;
    final userId = user.uid;
    List favorites =  (await FirebaseFirestore.instance.collection('users').doc(userId.toString())
        .get())['favorites'].cast<String>().toList();
    for(int i = 0; i < favorites.length; i++){
      var wordsToAdd = favorites[i].split(RegExp(r"(?<=[a-z])(?=[A-Z])"));
      var word = _alreadySaved(favorites[i], pairs);
      if(word != null) {
        savedSet.add(word);
      }
      else{
        savedSet.add(WordPair(wordsToAdd.first, wordsToAdd.last));
      }
    }
    notifyListeners();
  }

  Future <void> _addUserDoc() async {
    final User user = _auth.currentUser;
    final userId = user.uid;
    var doc = await FirebaseFirestore.instance.collection('users').doc(userId.toString()).get();
    if(!doc.exists){
      await  FirebaseFirestore.instance.collection('users').doc(userId.toString()).set({'favorites':[]});
    }
  }

  Future <void> _addUser() async {
    final User user = _auth.currentUser;
    final userId = user.uid;
    var doc = await FirebaseFirestore.instance.collection('users').doc(userId.toString()).get();
    if(!doc.exists){
      await  FirebaseFirestore.instance.collection('users').doc(userId.toString()).set({'favorites':[]});
    }
  }

  Future<void> _loadAvatar() async {
    firebaseStorage.Reference ref = firebaseStorage.FirebaseStorage.instance.ref().child(user.uid.toString());
    await ref.getDownloadURL().then((value) => _avatar = value);
    notifyListeners();
  }

  Future<bool> _onOut() async{
    await signOut();
    return true;
  }

}
