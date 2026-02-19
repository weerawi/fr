import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

/// Model class for storing user face data
class UserFaceData {
  final int? id;
  final String userId;
  final String userName;
  final List<List<double>> embeddings; // Multiple embeddings for robustness
  final DateTime createdAt;
  final DateTime updatedAt;

  UserFaceData({
    this.id,
    required this.userId,
    required this.userName,
    required this.embeddings,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'userName': userName,
      'embeddings': jsonEncode(embeddings),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory UserFaceData.fromMap(Map<String, dynamic> map) {
    return UserFaceData(
      id: map['id'],
      userId: map['userId'],
      userName: map['userName'],
      embeddings: (jsonDecode(map['embeddings']) as List)
          .map((e) => (e as List).map((v) => v as double).toList())
          .toList(),
      createdAt: DateTime.parse(map['createdAt']),
      updatedAt: DateTime.parse(map['updatedAt']),
    );
  }
}

/// Service for managing local database storage
class DatabaseService {
  static Database? _database;
  static const String DB_NAME = 'face_recognition.db';
  static const String TABLE_USERS = 'users';

  /// Get database instance (singleton pattern)
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  /// Initialize the database
  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), DB_NAME);
    
    return await openDatabase(
      path,
      version: 1,
      onCreate: (Database db, int version) async {
        await db.execute('''
          CREATE TABLE $TABLE_USERS (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            userId TEXT UNIQUE NOT NULL,
            userName TEXT NOT NULL,
            embeddings TEXT NOT NULL,
            createdAt TEXT NOT NULL,
            updatedAt TEXT NOT NULL
          )
        ''');
        print('Database created successfully');
      },
    );
  }

  /// Insert or update user face data
  Future<int> saveUser(UserFaceData userData) async {
    final db = await database;
    
    // Check if user exists
    final existing = await getUserByUserId(userData.userId);
    
    if (existing != null) {
      // Update existing user
      await db.update(
        TABLE_USERS,
        userData.toMap(),
        where: 'userId = ?',
        whereArgs: [userData.userId],
      );
      print('Updated user: ${userData.userName}');
      return existing.id!;
    } else {
      // Insert new user
      final id = await db.insert(
        TABLE_USERS,
        userData.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      print('Inserted new user: ${userData.userName}');
      return id;
    }
  }

  /// Get user by userId
  Future<UserFaceData?> getUserByUserId(String userId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      TABLE_USERS,
      where: 'userId = ?',
      whereArgs: [userId],
    );

    if (maps.isEmpty) return null;
    return UserFaceData.fromMap(maps.first);
  }

  /// Get all registered users
  Future<List<UserFaceData>> getAllUsers() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(TABLE_USERS);
    
    return List.generate(maps.length, (i) {
      return UserFaceData.fromMap(maps[i]);
    });
  }

  /// Delete user by userId
  Future<void> deleteUser(String userId) async {
    final db = await database;
    await db.delete(
      TABLE_USERS,
      where: 'userId = ?',
      whereArgs: [userId],
    );
    print('Deleted user: $userId');
  }

  /// Delete all users (for testing/reset)
  Future<void> deleteAllUsers() async {
    final db = await database;
    await db.delete(TABLE_USERS);
    print('Deleted all users');
  }

  /// Get total number of registered users
  Future<int> getUserCount() async {
    final db = await database;
    final count = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM $TABLE_USERS'),
    );
    return count ?? 0;
  }

  /// Close database connection
  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }
}
