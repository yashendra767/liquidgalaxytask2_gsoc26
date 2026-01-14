import 'package:shared_preferences/shared_preferences.dart';

class LgConnectionModel {
  String username ;
  String ip ;
  int port ;
  String password ;
  int screens ;

  static const String _keyUsername = 'lg_username' ;
  static const String _keyIp = 'lg_ip' ;
  static const String _keyPort = 'lg_port' ;
  static const String _keyPassword = 'lg_password' ;
  static const String _keyScreens = 'lg_screens' ;

  LgConnectionModel({
    this.username = '',
    this.ip = '',
    this.password = '',
    this.port = 22,
    this.screens = 3
  });

  Future<void> saveToPreference() async{
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUsername, username);
    await prefs.setString(_keyIp, ip);
    await prefs.setInt(_keyPort, port);
    await prefs.setString(_keyPassword, password);
    await prefs.setInt(_keyScreens, screens);
  }

  Future<LgConnectionModel> loadFromPreference() async{
    final prefs = await SharedPreferences.getInstance();
    return LgConnectionModel(
        username: prefs.getString(_keyUsername) ?? 'lg',
        ip: prefs.getString(_keyIp) ?? '' ,
        port: prefs.getInt(_keyPort) ?? 22,
        password: prefs.getString(_keyPassword) ?? "lg",
        screens: prefs.getInt(_keyScreens) ?? 3
    );
  }

  void updateConnection({
    String? username,
    String? ip,
    int? port,
    String? password,
    int? screens,
  }) {
    this.username = username ?? this.username;
    this.ip = ip ?? this.ip;
    this.port = port ?? this.port;
    this.password = password ?? this.password;
    this.screens = screens ?? this.screens;
  }

}