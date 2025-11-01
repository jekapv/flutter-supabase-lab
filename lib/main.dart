import 'package:flutter/material.dart';
import 'package:supabase/supabase.dart';

const String supabaseUrl = 'https://frvexfoezbscdbcvuxas.supabase.co';
const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZydmV4Zm9lemJzY2RiY3Z1eGFzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTk3NDY4ODgsImV4cCI6MjA3NTMyMjg4OH0.XDr9MFxBMX0P42a4MwjstxtZeh_Caqdyrfpfr7d9ec8';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Сообщения',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const AuthTabs(), // Начинаем с экрана авторизации
    );
  }
}

// ============ ЭКРАН СООБЩЕНИЙ (после входа) ============
class MessageScreen extends StatefulWidget {
  final String username; // можно передавать, если нужно

  const MessageScreen({super.key, this.username = ''});

  @override
  State<MessageScreen> createState() => _MessageScreenState();
}

class _MessageScreenState extends State<MessageScreen> {
  final supabase = SupabaseClient(supabaseUrl, supabaseAnonKey);
  final messageCtrl = TextEditingController();

  Future<void> _showConfirmationDialog(String message) async {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Подтвердите отправку'),
          content: Text('Вы уверены, что хотите отправить сообщение?\n\n"$message"'),
          actions: <Widget>[
            TextButton(
              child: const Text('Нет'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              child: const Text('Да'),
              onPressed: () {
                Navigator.of(context).pop();
                _sendMessage(message);
              },
            ),
          ],
        );
      },
    );
  }

  void _sendMessage(String message) {
    supabase
        .from('messages')
        .insert({'message': message})
        .then((_) {
          messageCtrl.clear();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Сообщение добавлено')),
          );
          setState(() {});
        })
        .catchError((e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ошибка: $e')),
          );
        });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Сообщения'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const AuthTabs()),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: messageCtrl,
                  decoration: const InputDecoration(labelText: 'Введите сообщение'),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    final message = messageCtrl.text.trim();
                    if (message.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Введите сообщение')),
                      );
                      return;
                    }
                    _showConfirmationDialog(message);
                  },
                  child: const Text('Отправить'),
                ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<dynamic>>(
              future: _loadMessages(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Ошибка: ${snapshot.error}'));
                }
                if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                  return ListView.builder(
                    itemCount: snapshot.data!.length,
                    itemBuilder: (context, i) {
                      final msg = snapshot.data![i];
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        child: ListTile(
                          title: Text(msg['message']),
                          subtitle: Text('Отправлено: ${msg['created_at']}'),
                        ),
                      );
                    },
                  );
                }
                return const Center(child: Text('Нет сообщений'));
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<List<dynamic>> _loadMessages() async {
    final data = await supabase.from('messages').select().order('created_at', ascending: false);
    return data as List<dynamic>;
  }
}

// ============ ЭКРАН АВТОРИЗАЦИИ ============
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final supabase = SupabaseClient(supabaseUrl, supabaseAnonKey);
  final usernameCtrl = TextEditingController();
  final passwordCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Авторизация')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: usernameCtrl,
              decoration: const InputDecoration(labelText: 'Логин'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: passwordCtrl,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Пароль'),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () async {
                final username = usernameCtrl.text.trim();
                final password = passwordCtrl.text.trim();

                if (username.isEmpty || password.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Заполните все поля')),
                  );
                  return;
                }

                try {
                  final data = await supabase
                      .from('users')
                      .select()
                      .eq('username', username)
                      .eq('password', password);

                  if ((data as List).isNotEmpty) {
                    // ✅ УСПЕШНЫЙ ВХОД → ПЕРЕХОД НА СООБЩЕНИЯ
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MessageScreen(username: username),
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('❌ Неверный логин или пароль')),
                    );
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Ошибка: $e')),
                  );
                }
              },
              child: const Text('Войти'),
            ),
          ],
        ),
      ),
    );
  }
}

// ============ ЭКРАН РЕГИСТРАЦИИ ============
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final supabase = SupabaseClient(supabaseUrl, supabaseAnonKey);
  final usernameCtrl = TextEditingController();
  final passwordCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Регистрация')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: usernameCtrl,
              decoration: const InputDecoration(labelText: 'Логин'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: passwordCtrl,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Пароль'),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () async {
                final username = usernameCtrl.text.trim();
                final password = passwordCtrl.text.trim();

                if (username.isEmpty || password.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Заполните все поля')),
                  );
                  return;
                }

                try {
                  await supabase
                      .from('users')
                      .insert({'username': username, 'password': password});

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('✅ Пользователь зарегистрирован')),
                  );
                  usernameCtrl.clear();
                  passwordCtrl.clear();
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Ошибка: $e')),
                  );
                }
              },
              child: const Text('Зарегистрироваться'),
            ),
          ],
        ),
      ),
    );
  }
}

// ============ ВКЛАДКИ АВТОРИЗАЦИИ/РЕГИСТРАЦИИ ============
class AuthTabs extends StatefulWidget {
  const AuthTabs({super.key});

  @override
  State<AuthTabs> createState() => _AuthTabsState();
}

class _AuthTabsState extends State<AuthTabs> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    LoginScreen(),
    RegisterScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.login),
            label: 'Авторизация',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_add),
            label: 'Регистрация',
          ),
        ],
      ),
    );
  }
}