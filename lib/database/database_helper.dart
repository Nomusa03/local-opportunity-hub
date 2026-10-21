import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();

  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }

    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final databasePath = await getDatabasesPath();

    final path = join(databasePath, 'local_opportunity_hub.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE saved_opportunities (
            id TEXT NOT NULL,
            user_id TEXT NOT NULL,
            title TEXT NOT NULL,
            company TEXT NOT NULL,
            type TEXT NOT NULL,
            PRIMARY KEY (id, user_id)
          )
        ''');
      },
    );
  }

  Future<void> saveOpportunity({
    required String id,
    required String title,
    required String company,
    required String type,
  }) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw Exception('No user is logged in.');
    }

    final db = await database;

    await db.insert('saved_opportunities', {
      'id': id,
      'user_id': user.uid,
      'title': title,
      'company': company,
      'type': type,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getSavedOpportunities() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return [];
    }

    final db = await database;

    return await db.query(
      'saved_opportunities',
      where: 'user_id = ?',
      whereArgs: [user.uid],
    );
  }

  Future<void> deleteSavedOpportunity(String opportunityId) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return;
    }

    final db = await database;

    await db.delete(
      'saved_opportunities',
      where: 'id = ? AND user_id = ?',
      whereArgs: [opportunityId, user.uid],
    );
  }
}
