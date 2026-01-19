import 'dart:async';
import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import '../models/lg_connection_model.dart';

class LgService {
  static final LgService _instance = LgService._internal();
  factory LgService() => _instance;
  LgService._internal();

  final LgConnectionModel _lgConnectionModel = LgConnectionModel();
  SSHClient? _client;
  bool _isConnected = false;

  bool get isConnected => _isConnected;
  LgConnectionModel get connectionModel => _lgConnectionModel;


  //Connection establish
  Future<void> initializeConnection() async {
    try {
      final savedModel = await _lgConnectionModel.loadFromPreference();
      _lgConnectionModel.updateConnection(
        ip: savedModel.ip,
        port: savedModel.port,
        username: savedModel.username,
        password: savedModel.password,
        screens: savedModel.screens,
      );
      await connectToLG();
    } catch (e) {
      print("Initialization error: $e");
    }
  }

  Future<bool?> connectToLG() async {
    try {
      final socket = await SSHSocket.connect(_lgConnectionModel.ip, _lgConnectionModel.port);
      _client = SSHClient(
        socket,
        username: _lgConnectionModel.username,
        onPasswordRequest: () => _lgConnectionModel.password,
      );
      _isConnected = true;
      print("Connected to LG");

      await flyToIndia();

      return true;
    } on SocketException catch (e) {
      print('Failed to Connect: $e');
      return false;
    }
  }

  void disconnect() {
    _client?.close();
    _client = null;
    _isConnected = false;
  }

  Future<dynamic> execute(String command, String successMsg) async {
    if (_client == null) return null;
    try {
      final result = await _client!.execute(command);
      print(successMsg);
      return result;
    } catch (e) {
      print('Error executing command: $e');
      return null;
    }
  }

  Future<bool> query(String content) async {
    final result = await execute(
        'echo "$content" > /tmp/query.txt',
        'Query Sent: $content'
    );
    return result != null;
  }

  Future<void> flyTo(String kmlViewTag) async {
    String cleanLookAt = kmlViewTag.replaceAll(RegExp(r'\s+'), '');
    await query('flytoview=$cleanLookAt');
  }

  //upload kml fun
  Future<void> uploadKml(String content, String fileName) async {
    if (_client == null) return;
    try {
      final randomNumber = DateTime.now().millisecondsSinceEpoch % 1000;
      final fileNameWithRandom = fileName.replaceAll('.kml', '_$randomNumber.kml');
      final remotePath = '/var/www/html/$fileNameWithRandom';

      final sftp = await _client?.sftp();
      if (sftp == null) return;

      //Opening file
      final file = await sftp.open(
        remotePath,
        mode: SftpFileOpenMode.truncate | SftpFileOpenMode.create | SftpFileOpenMode.write,
      );

      //content on to file
      final directory = await getTemporaryDirectory();
      final localFile = File('${directory.path}/$fileNameWithRandom');
      await localFile.writeAsString(content);

      final fileStream = localFile.openRead();
      int offset = 0;
      await for (final chunk in fileStream) {
        final typedChunk = Uint8List.fromList(chunk);
        await file.write(Stream.fromIterable([typedChunk]), offset: offset);
        offset += typedChunk.length;
      }

      //Close file
      await file.close();

      await execute('chmod 644 $remotePath', 'Permissions set for $fileNameWithRandom');

      //Updating lg registry with kmls.txt
      await execute(
          'echo "http://lg1:81/$fileNameWithRandom" > /var/www/html/kmls.txt',
          'KML uploaded & Registered'
      );
    } catch (e) {
      debugPrint('Error in uploading kml file: $e');
    }
  }

  int calculateLeftMostScreen(int screenCount) {
    return screenCount == 1 ? 1 : (screenCount / 2).floor() + 2;
  }

  int calculateRightMostScreen(int screenCount) {
    return screenCount == 1 ? 1 : (screenCount / 2).floor() + 1;
  }


  //logo sending
  Future<void> sendLogo() async {
    int leftMostScreen = calculateLeftMostScreen(_lgConnectionModel.screens);
    String imagePath = "http://lg1:81/logo.png";

    try {
      final byteData = await rootBundle.load('assets/logo.png');

      final sftp = await _client?.sftp();
      if (sftp != null) {
        final remoteFile = await sftp.open('/var/www/html/logo.png',
            mode: SftpFileOpenMode.write | SftpFileOpenMode.create | SftpFileOpenMode.truncate);

        final bytes = byteData.buffer.asUint8List();
        await remoteFile.write(Stream.value(bytes));
        await remoteFile.close();

        await execute('chmod 644 /var/www/html/logo.png', 'Logo permissions set');
      }
    } catch (e) {
      debugPrint("Error uploading logo image: $e");

    }

    String kmlContent = '''<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://www.opengis.net/kml/2.2" xmlns:gx="http://www.google.com/kml/ext/2.2" xmlns:kml="http://www.opengis.net/kml/2.2" xmlns:atom="http://www.w3.org/2005/Atom">
  <Document>
    <name>Logo</name>
    <ScreenOverlay>
      <name>Logo</name>
      <Icon>
        <href>$imagePath</href>
      </Icon>
      <overlayXY x="0" y="1" xunits="fraction" yunits="fraction"/>
      <screenXY x="0.02" y="0.95" xunits="fraction" yunits="fraction"/>
      <rotationXY x="0" y="0" xunits="fraction" yunits="fraction"/>
      <size x="300" y="300" xunits="pixels" yunits="pixels"/>
    </ScreenOverlay>
  </Document>
</kml>''';

    await execute(
        "echo '$kmlContent' > /var/www/html/kml/slave_$leftMostScreen.kml",
        'Logo KML Sent'
    );

    await forceRefresh(leftMostScreen);
  }

  //city kml self created
  Future<void> sendLucknowKml() async {
    const int height = 4000;

    String kml = '''<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://www.opengis.net/kml/2.2">
<Document>
    <name>Lucknow City</name>
    <Style id="polyStyle">
        <LineStyle><color>ff0000ff</color><width>5</width></LineStyle>
        <PolyStyle><color>7f0000ff</color></PolyStyle>
    </Style>
    <Placemark>
        <name>Lucknow Zone</name>
        <styleUrl>#polyStyle</styleUrl>
        <Polygon>
            <extrude>1</extrude> <tessellate>1</tessellate>
            <altitudeMode>relativeToGround</altitudeMode> <outerBoundaryIs>
                <LinearRing>
                    <coordinates>
                        80.957,26.990,$height 80.927,27.000,$height 80.905,27.003,$height 80.878,27.004,$height 
                        80.864,26.992,$height 80.849,26.975,$height 80.836,26.957,$height 80.829,26.945,$height 
                        80.826,26.921,$height 80.818,26.877,$height 80.806,26.865,$height 80.798,26.842,$height 
                        80.797,26.832,$height 80.805,26.807,$height 80.817,26.782,$height 80.833,26.749,$height 
                        80.835,26.731,$height 80.848,26.725,$height 80.859,26.722,$height 80.867,26.718,$height 
                        80.878,26.720,$height 80.890,26.723,$height 80.901,26.722,$height 80.914,26.724,$height 
                        80.925,26.726,$height 80.937,26.727,$height 80.949,26.725,$height 80.966,26.726,$height 
                        80.983,26.730,$height 81.006,26.743,$height 81.018,26.754,$height 81.038,26.770,$height 
                        81.048,26.779,$height 81.056,26.789,$height 81.065,26.805,$height 81.067,26.826,$height 
                        81.070,26.841,$height 81.078,26.854,$height 81.083,26.869,$height 81.083,26.882,$height 
                        81.076,26.901,$height 81.069,26.921,$height 81.067,26.946,$height 81.067,26.961,$height 
                        81.071,26.968,$height 81.073,26.973,$height 81.065,26.978,$height 81.051,26.979,$height 
                        81.039,26.986,$height 81.024,26.993,$height 81.016,26.995,$height 81.011,27.004,$height 
                        81.006,27.011,$height 80.999,27.017,$height 80.992,27.014,$height 80.990,27.004,$height 
                        80.987,27.000,$height 80.978,26.996,$height 80.972,26.992,$height 80.957,26.990,$height 
                    </coordinates>
                </LinearRing>
            </outerBoundaryIs>
        </Polygon>
    </Placemark>
</Document>
</kml>''';

    await uploadKml(kml, 'lucknow.kml');

    await flyTo('<LookAt>'
        '<longitude>80.92</longitude>'
        '<latitude>26.88</latitude>'
        '<range>65000</range>'
        '<tilt>60</tilt>'
        '<heading>0</heading>'
        '<altitudeMode>relativeToGround</altitudeMode>'
        '</LookAt>');
  }

  //US major cities kml self created
  Future<void> sendMajorCitiesKml() async {
    String flyToLookAt = '<LookAt>'
        '<longitude>-108.7454625994195</longitude>'
        '<latitude>40.8277424054128</latitude>'
        '<altitude>-1839.469560201281</altitude>'
        '<heading>355.4641792842396</heading>'
        '<tilt>0</tilt>'
        '<range>7585653.601777554</range>'
        '<altitudeMode>absolute</altitudeMode>'
        '</LookAt>';

    String kml = '''<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://www.opengis.net/kml/2.2" xmlns:gx="http://www.google.com/kml/ext/2.2" xmlns:kml="http://www.opengis.net/kml/2.2" xmlns:atom="http://www.w3.org/2005/Atom">
<Document>
    <name>Untitled map</name>
    <gx:CascadingStyle kml:id="__managed_style_2B7FEA433C3CDBA35CEC">
        <Style>
            <IconStyle>
                <scale>1.2</scale>
                <Icon>
                    <href>https://earth.google.com/earth/document/icon?color=1976d2&amp;id=2000&amp;scale=4</href>
                </Icon>
                <hotSpot x="64" y="128" xunits="pixels" yunits="insetPixels"/>
            </IconStyle>
            <LabelStyle>
            </LabelStyle>
            <LineStyle>
                <color>ff2dc0fb</color>
                <width>4.8</width>
            </LineStyle>
            <PolyStyle>
                <color>40ffffff</color>
            </PolyStyle>
            <BalloonStyle>
                <displayMode>hide</displayMode>
            </BalloonStyle>
        </Style>
    </gx:CascadingStyle>
    <gx:CascadingStyle kml:id="__managed_style_1C0D91FBB03CDBA35CEC">
        <Style>
            <IconStyle>
                <Icon>
                    <href>https://earth.google.com/earth/document/icon?color=1976d2&amp;id=2000&amp;scale=4</href>
                </Icon>
                <hotSpot x="64" y="128" xunits="pixels" yunits="insetPixels"/>
            </IconStyle>
            <LabelStyle>
            </LabelStyle>
            <LineStyle>
                <color>ff2dc0fb</color>
                <width>3.2</width>
            </LineStyle>
            <PolyStyle>
                <color>40ffffff</color>
            </PolyStyle>
            <BalloonStyle>
                <displayMode>hide</displayMode>
            </BalloonStyle>
        </Style>
    </gx:CascadingStyle>
    <StyleMap id="__managed_style_0A83859D0A3CDBA35CEC">
        <Pair>
            <key>normal</key>
            <styleUrl>#__managed_style_1C0D91FBB03CDBA35CEC</styleUrl>
        </Pair>
        <Pair>
            <key>highlight</key>
            <styleUrl>#__managed_style_2B7FEA433C3CDBA35CEC</styleUrl>
        </Pair>
    </StyleMap>
    <Placemark id="095367F8CA3CDBA35CDE">
        <name>Major cities US</name>
        <LookAt>
            <longitude>-108.7454625994195</longitude>
            <latitude>40.8277424054128</latitude>
            <altitude>-1839.469560201281</altitude>
            <heading>355.4641792842396</heading>
            <tilt>0</tilt>
            <gx:fovy>35</gx:fovy>
            <range>7585653.601777554</range>
            <altitudeMode>absolute</altitudeMode>
        </LookAt>
        <styleUrl>#__managed_style_0A83859D0A3CDBA35CEC</styleUrl>
        <Polygon>
            <outerBoundaryIs>
                <LinearRing>
                    <coordinates>
                        -73.85987873686665,40.78345007966847,0 -122.534633014182,47.89694136096103,0 -122.3659367102096,37.85315897218551,0 -73.85987873686665,40.78345007966847,0 
                    </coordinates>
                </LinearRing>
            </outerBoundaryIs>
        </Polygon>
    </Placemark>
</Document>
</kml>''';

    await uploadKml(kml, 'major_cities_us.kml');
    await flyTo(flyToLookAt);
  }

  //clean logo fun
  Future<void> cleanLogo() async{
    int leftMostScreen = calculateLeftMostScreen(_lgConnectionModel.screens);
    const blankKml =
    '''<?xml version="1.0" encoding="UTF-8"?><kml xmlns="http://www.opengis.net/kml/2.2">
        <Document><name>Logo</name></Document></kml>''';
    await execute("echo '$blankKml' > /var/www/html/kml/slave_$leftMostScreen.kml", "Logo Cleaned");
    await forceRefresh(leftMostScreen);

  }


  //clean kml fun
  Future<bool> cleanKML() async{
    bool allSuccessful = true ;
    final clearCommand =  'echo "exittour=true" > /tmp/query.txt && > /var/www/html/kmls.txt';

    final headerCleared = await execute(clearCommand, 'KMLs.txt cleared');

    allSuccessful = allSuccessful && (headerCleared != null);
    int rightMost = calculateRightMostScreen(_lgConnectionModel.screens);
    const blankKml =
    '''<?xml version="1.0" encoding="UTF-8"?><kml xmlns="http://www.opengis.net/kml/2.2">
        <Document><name>Empty</name></Document></kml>''';

    final cleared = await execute("echo '$blankKml' > /var/www/html/kml/slave_$rightMost.kml",'Rightmost screen cleared');

    allSuccessful = allSuccessful && (cleared != null);

    await forceRefresh(rightMost);
    return allSuccessful ;

  }

  Future<void> forceRefresh(int screenNumber) async {
    try {
      final search = '<href>##LG_PHPIFACE##kml\\/slave_$screenNumber.kml<\\/href>';
      final replace = '<href>##LG_PHPIFACE##kml\\/slave_$screenNumber.kml<\\/href><refreshMode>onInterval<\\/refreshMode><refreshInterval>1<\\/refreshInterval>';

      final addCommand = 'echo ${_lgConnectionModel.password} | sudo -S sed -i "s|$search|$replace|" ~/earth/kml/slave/myplaces.kml';

      await execute(
        "sshpass -p ${_lgConnectionModel.password} ssh -t lg$screenNumber '$addCommand'",
        'Refresh added to screen $screenNumber',
      );

      await Future.delayed(const Duration(seconds: 1));

      final searchWithRefresh = '<href>##LG_PHPIFACE##kml\\/slave_$screenNumber.kml<\\/href><refreshMode>onInterval<\\/refreshMode><refreshInterval>[0-9]+<\\/refreshInterval>';
      final restore = '<href>##LG_PHPIFACE##kml\\/slave_$screenNumber.kml<\\/href>';

      final removeCommand = 'echo ${_lgConnectionModel.password} | sudo -S sed -i "s|$searchWithRefresh|$restore|" ~/earth/kml/slave/myplaces.kml';

      await execute(
          "sshpass -p ${_lgConnectionModel.password} ssh -t lg$screenNumber '$removeCommand'",
          'Refresh removed from screen $screenNumber'
      );
    } catch (e) {
      print('Error in forceRefresh: $e');
    }
  }

  //after connect fly to fun
  Future<void> flyToIndia() async {
    await query('search=India');
  }

  void updateConnectionSettings({
    required String ip,
    required int port,
    required String username,
    required String password,
    required int screens,
  }) {
    _lgConnectionModel.updateConnection(
      ip: ip,
      port: port,
      username: username,
      password: password,
      screens: screens,
    );
  }

  Future<void> relaunchLG() async {
    final password = _lgConnectionModel.password;
    final cmd = """
      RELAUNCH_CMD="\\
      if [ -f /etc/init/lxdm.conf ]; then export SERVICE=lxdm;
      elif [ -f /etc/init/lightdm.conf ]; then export SERVICE=lightdm;
      else exit 1; fi
      if [[ \\\$(service \\\$SERVICE status) =~ 'stop' ]]; then
        echo $password | sudo -S service \\\${SERVICE} start;
      else
        echo $password | sudo -S service \\\${SERVICE} restart;
      fi
      " && sshpass -p $password ssh -x -t lg@lg1 "\$RELAUNCH_CMD\"""";

    await execute(cmd, 'LG Relaunched');
  }

  Future<void> reboot() async {
    final password = _lgConnectionModel.password;
    int screens = _lgConnectionModel.screens;

    for (int i = screens; i > 1; i--) {
      await execute(
          'sshpass -p $password ssh -t lg$i "echo $password | sudo -S reboot"',
          'Rebooting slave $i'
      );
    }
    await execute(
        'sshpass -p $password ssh -t lg1 "echo $password | sudo -S reboot"',
        'Rebooting Master'
    );
  }

  Future<void> shutdown() async {
    final password = _lgConnectionModel.password;
    int screens = _lgConnectionModel.screens;

    for (int i = screens; i > 1; i--) {
      await execute(
          'sshpass -p $password ssh -t lg$i "echo $password | sudo -S poweroff"',
          'Shutting down slave $i'
      );
    }
    await execute(
        'sshpass -p $password ssh -t lg1 "echo $password | sudo -S poweroff"',
        'Shutting down Master'
    );
  }

}


