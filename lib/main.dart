import 'package:flutter/material.dart';
import 'package:supabase/supabase.dart';

const String supabaseUrl = 'https://kszzgrxangxxxdrojzvd.supabase.co';
const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imtzenpncnhhbmd4eHhkcm9qenZkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjE1NzI5MDYsImV4cCI6MjA3NzE0ODkwNn0.swkRooXHapuVU788MLChOdcxTTrYf3ECC3K0J0nkXeo';


void main() {
  runApp(const MyApp());
}


class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Книги', // Название вкладки в браузере
      theme: ThemeData(primarySwatch: Colors.blue), // Цветовая тема
      home: const BookScreen(), // Главный экран приложения
    );
  }
}

// Главный экран: форма + список книг из базы
class BookScreen extends StatefulWidget {
  const BookScreen({super.key});

  @override
  State<BookScreen> createState() => _BookScreenState();
}

class _BookScreenState extends State<BookScreen> {
  // Создаём "мост" к Supabase — через него будем читать и писать данные
  final supabase = SupabaseClient(supabaseUrl, supabaseAnonKey);

  // Эти контроллеры "хранят" текст, который пользователь вводит в поля
  final titleCtrl = TextEditingController();
  final authorCtrl = TextEditingController();
  final yearCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Книги')), // Верхняя панель
      body: Column(
        children: [
          //  ФОРМА ДОБАВЛЕНИЯ КНИГИ 
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Название')),
                TextField(controller: authorCtrl, decoration: const InputDecoration(labelText: 'Автор')),
                TextField(controller: yearCtrl, decoration: const InputDecoration(labelText: 'Год')),
                ElevatedButton(
                  onPressed: () {
                    // Получаем текст из полей и убираем лишние пробелы
                    final title = titleCtrl.text.trim();
                    final author = authorCtrl.text.trim();
                    final yearStr = yearCtrl.text.trim();

                    // Проверка: все поля заполнены?
                    if (title.isEmpty || author.isEmpty || yearStr.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Заполните все поля')),
                      );
                      return;
                    }

                    // Пробуем превратить год в число
                    final year = int.tryParse(yearStr);
                    if (year == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Год — число')),
                      );
                      return;
                    }

                    // ОТПРАВЛЯЕМ ДАННЫЕ В SUPABASE 
                    supabase
                        .from('books') // Выбираем таблицу 'books'
                        .insert({
                          'title': title,
                          'author': author,
                          'year': year,
                        })
                        // Если всё прошло успешно:
                        .then((_) {
                          // Очищаем поля ввода
                          titleCtrl.clear();
                          authorCtrl.clear();
                          yearCtrl.clear();
                          // Показываем уведомление
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Добавлено')),
                          );
                          // Обновляем список книг на экране
                          setState(() {});
                        })
                        // Если произошла ошибка:
                        .catchError((e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Ошибка: $e')),
                          );
                        });
                  },
                  child: const Text('Добавить'),
                ),
              ],
            ),
          ),

          //  СПИСОК КНИГ ИЗ БАЗЫ 
          // FutureBuilder автоматически обрабатывает загрузку, ошибку и данные
          Expanded(
            child: FutureBuilder<List<dynamic>>(
              future: _loadBooks(), // Эта функция загружает книги
              builder: (context, snapshot) {
                // Пока идёт загрузка — показываем кружок
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                // Если произошла ошибка — показываем текст ошибки
                if (snapshot.hasError) {
                  return Center(child: Text('Ошибка: ${snapshot.error}'));
                }

                // Если данные получены и список не пустой — показываем книги
                if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                  return ListView.builder(
                    itemCount: snapshot.data!.length,
                    itemBuilder: (context, i) {
                      final book = snapshot.data![i];
                      // Каждая книга — это карточка с названием и автором
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        child: ListTile(
                          title: Text(book['title']),
                          subtitle: Text('${book['author']}, ${book['year']}'),
                        ),
                      );
                    },
                  );
                }

                // Если данных нет — пишем "Нет книг"
                return const Center(child: Text('Нет книг'));
              },
            ),
          ),
        ],
      ),
    );
  }

  //  ФУНКЦИЯ: ЗАГРУЗИТЬ КНИГИ ИЗ SUPABASE 
  // Она делает запрос: SELECT * FROM books
  Future<List<dynamic>> _loadBooks() async {
    final data = await supabase.from('books').select();
    return data as List<dynamic>;
  }
}