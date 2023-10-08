import 'package:desi_karaoke_lite/main.dart';
import 'package:firebase_auth/firebase_auth.dart'
    hide PhoneAuthProvider;
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_signin_button/button_builder.dart';
import 'package:flutter_signin_button/button_view.dart';
import 'package:flutter_signin_button/flutter_signin_button.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_ui_auth/firebase_ui_auth.dart';
import 'package:firebase_ui_oauth_google/firebase_ui_oauth_google.dart';
import 'package:flutter/material.dart';
import 'firebase_options.dart';

const GOOGLE_CLIENT_ID = '837759484127-orc1b2i495rq62s4i1gab2dfjblcbetp.apps.googleusercontent.com';





class LoginScreen extends StatelessWidget {
  static const MethodChannel _channel = const MethodChannel('firebase_auth_ui');
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Login",
      home: Scaffold(
        body: LoginPage(),
      ),
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({
    Key? key,
  }) : super(key: key);

  @override
  _LoginPageState createState() => _LoginPageState();
}

class FirebaseAuthUIExample extends StatelessWidget {
  const FirebaseAuthUIExample({super.key});

  String get initialRoute {
    final user = FirebaseAuth.instance.currentUser;

    return switch (user) {
      null => '/',
      User(emailVerified: false, email: final String _) => '/verify-email',
      _ => '/profile',
    };
  }

  @override
  Widget build(BuildContext context) {
    final buttonStyle = ButtonStyle(
      padding: MaterialStateProperty.all(const EdgeInsets.all(12)),
      shape: MaterialStateProperty.all(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );

    final mfaAction = AuthStateChangeAction<MFARequired>(
          (context, state) async {
        final nav = Navigator.of(context);

        await startMFAVerification(
          resolver: state.resolver,
          context: context,
        );

        nav.pushReplacementNamed('/profile');
      },
    );

    return MaterialApp(
      theme: ThemeData(
        brightness: Brightness.light,
        visualDensity: VisualDensity.standard,
        useMaterial3: true,
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(style: buttonStyle),
        textButtonTheme: TextButtonThemeData(style: buttonStyle),
        outlinedButtonTheme: OutlinedButtonThemeData(style: buttonStyle),
      ),
      initialRoute: initialRoute,
      routes: {
        '/': (context) {
          return SignInScreen(
            actions: [
              ForgotPasswordAction((context, email) {
                Navigator.pushNamed(
                  context,
                  '/forgot-password',
                  arguments: {'email': email},
                );
              }),
              VerifyPhoneAction((context, _) {
                Navigator.pushNamed(context, '/phone');
              }),
              AuthStateChangeAction((context, state) {
                final user = switch (state) {
                  SignedIn(user: final user) => user,
                  CredentialLinked(user: final user) => user,
                  UserCreated(credential: final cred) => cred.user,
                  _ => null,
                };

                switch (user) {
                  case User(emailVerified: true):
                    Navigator.pushReplacementNamed(context, '/profile');
                  case User(emailVerified: false, email: final String _):
                    Navigator.pushNamed(context, '/verify-email');
                }
              }),
              mfaAction,
              EmailLinkSignInAction((context) {
                Navigator.pushReplacementNamed(context, '/email-link-sign-in');
              }),
            ],
            styles: const {
              EmailFormStyle(signInButtonVariant: ButtonVariant.filled),
            },

            subtitleBuilder: (context, action) {
              final actionText = switch (action) {
                AuthAction.signIn => 'Please sign in to continue.',
                AuthAction.signUp => 'Please create an account to continue',
                _ => throw Exception('Invalid action: $action'),
              };

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text('Welcome to Firebase UI! $actionText.'),
              );
            },
            footerBuilder: (context, action) {
              final actionText = switch (action) {
                AuthAction.signIn => 'signing in',
                AuthAction.signUp => 'registering',
                _ => throw Exception('Invalid action: $action'),
              };

              return Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(
                    'By $actionText, you agree to our terms and conditions.',
                    style: const TextStyle(color: Colors.grey),
                  ),
                ),
              );
            },
          );
        },
        '/verify-email': (context) {
          return EmailVerificationScreen(
            actions: [
              EmailVerifiedAction(() {
                Navigator.pushReplacementNamed(context, '/profile');
              }),
              AuthCancelledAction((context) {
                FirebaseUIAuth.signOut(context: context);
                Navigator.pushReplacementNamed(context, '/');
              }),
            ],
          );
        },
        '/phone': (context) {
          return PhoneInputScreen(
            actions: [
              SMSCodeRequestedAction((context, action, flowKey, phone) {
                Navigator.of(context).pushReplacementNamed(
                  '/sms',
                  arguments: {
                    'action': action,
                    'flowKey': flowKey,
                    'phone': phone,
                  },
                );
              }),
            ],
          );
        },
        '/sms': (context) {
          final arguments = ModalRoute.of(context)?.settings.arguments
          as Map<String, dynamic>?;

          return SMSCodeInputScreen(
            actions: [
              AuthStateChangeAction<SignedIn>((context, state) {
                Navigator.of(context).pushReplacementNamed('/profile');
              })
            ],
            flowKey: arguments?['flowKey'],
            action: arguments?['action'],

          );
        },

      },
    );
  }
}

/*
class LoginSignUp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final providers = [PhoneAuthProvider()];

    return MaterialApp(
      initialRoute: FirebaseAuth.instance.currentUser == null ? '/sign-in' : '/profile',
      routes: {
        '/sign-in': (context) {
          return SignInScreen(
            providers: providers,
            actions: [
              AuthStateChangeAction<SignedIn>((context, state) {
                Navigator.pushReplacementNamed(context, '/profile');
              }),
            ],
          );
        },
        '/profile': (context) {
          return ProfileScreen(
            providers: providers,
            actions: [
              SignedOutAction((context) {
                Navigator.pushReplacementNamed(context, '/sign-in');
              }),
            ],
          );
        },
      },
    );
  }
}
*/

class _LoginPageState extends State<LoginPage> {
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  var nameEditingController = TextEditingController();
  var globalKey = GlobalKey<FormState>();
  late DatabaseReference userRef;
  bool showCustomWidget = false;


  @override
  Widget build(BuildContext context) {
    return Container(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: <Widget>[
            Spacer(flex: 3),
            Text(
              "Welcome to",
              style: Theme.of(context).textTheme.displaySmall,
            ),
            Text(
              "Desi Karaoke",
              style: Theme.of(context).textTheme.displayMedium,
            ),
            Spacer(flex: 4),
            Column(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    "Please, sign in to continue:",
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),

                // SignInButton(
                //   Buttons.Google,
                //   onPressed: () {
                //     _handleSignIn();
                //   }, // default: false
                // ),
                // SignInButtonBuilder(
                //   text: "Sign In with Phone",
                //   backgroundColor: Colors.blueGrey[700],
                //   onPressed: () {},
                //   icon: Icons.phone,
                // ),
                ElevatedButton(child: Text("Get Started"),onPressed: (){
                  Navigator.push(context, MaterialPageRoute(builder: (context)=>FirebaseAuthUIExample()),);
                },)
              ],
            ),
            Spacer(
              flex: 1,
            )
          ],
        ),
      ),
    );
  }

  void _handleSignIn(user) async {
    // final GoogleSignInAccount googleUser = await _googleSignIn.signIn();
    // final GoogleSignInAuthentication googleAuth =
    //     await googleUser.authentication;

    // final AuthCredential credential = GoogleAuthProvider.getCredential(
    //   accessToken: googleAuth.accessToken,
    //   idToken: googleAuth.idToken,
    // );

    // final User user = (await _auth.signInWithCredential(credential)).user;
    // print(user.uid);
    userRef = FirebaseDatabase.instance.ref().child("users/${user.uid}");

    userRef.once().then((data) {
      if (data.snapshot.value == null) {
        showDialog(
          barrierDismissible: false,
          context: context,
          builder: (context) {
            return AlertDialog(
              title: Text("Your Full Name:"),
              content: Form(
                key: globalKey,
                child: TextFormField(
                  textCapitalization: TextCapitalization.words,
                  maxLines: 1,
                  controller: nameEditingController,
                  validator: (val) {
                    print("validating: $val");
                    if (val!.length < 2) {
                      return "Name too short";
                    } else
                      return null;
                  },
                  decoration: InputDecoration(
                      hintMaxLines: 1, hintText: "Firstname Lastname"),
                ),
              ),
              actions: <Widget>[
                TextButton(
                  child: Text("Cancel"),
                  onPressed: () {
                    Navigator.pop(context);
                    _auth.signOut();
                  },
                ),
                TextButton(
                  child: Text("Confirm"),
                  onPressed: submitName,
                ),
              ],
            );
          },
        );
      } else {
        onSuccessfulLogin();
      }
    });
  }

  void onSuccessfulLogin() {
    Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (BuildContext context) => MyApp()));
  }

  @override
  void dispose() {
    nameEditingController.dispose();
    super.dispose();
  }

  void submitName() {
    print("submit is pressed");
    State<StatefulWidget>? state = globalKey.currentState;
    if (globalKey.currentState!.validate()) {
      var signUpData = Map<String, dynamic>();
      signUpData['name'] = nameEditingController.text;
      signUpData['signuptime'] = ServerValue.timestamp;
      signUpData['currenttime'] = ServerValue.timestamp;
      userRef.set(signUpData).whenComplete(() {
        Navigator.of(context, rootNavigator: true).pop();
        onSuccessfulLogin();
      }).catchError((error) {
        print("Aight imma head out");
        _auth.signOut();
      });
    }
    /*State<StatefulWidget>? state = globalKey.currentState;
    if (state!.validate()) {
      var signUpData = Map<String, dynamic>();
      signUpData['name'] = nameEditingController.text;
      signUpData['signuptime'] = ServerValue.timestamp;
      signUpData['currenttime'] = ServerValue.timestamp;
      userRef?.set(signUpData)?.whenComplete(() {
        Navigator.of(context, rootNavigator: true).pop();
        onSuccessfulLogin();
      })?.catchError((error) {
        print("Aight imma head out");
        _auth.signOut();
      });
    }*/
  }

  void launchNativeSignInUi() {

    /*FirebaseAuthUi.instance().launchAuth([
          // AuthProvider.email(),
          // Google ,facebook, twitter and phone auth providers are commented because this example
          // isn't configured to enable them. Please follow the README and uncomment
          // them if you want to integrate them in your project.

          AuthProvider.google(),
          // AuthProvider.facebook(),
          // AuthProvider.twitter(),
          AuthProvider.phone(),
        ]).then((firebaseUser) {
          _handleSignIn(firebaseUser);
          
        }).catchError((error) {
          if (error is PlatformException) {
            setState(() {
              if (error.code == FirebaseAuthUi.kUserCancelledError) {
                // _error = "User cancelled login";
              } else {
                // _error = error.message ?? "Unknown error!";
              }
            });
          }
        });*/
  }

}
