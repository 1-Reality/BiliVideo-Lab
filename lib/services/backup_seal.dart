import 'dart:convert';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/api.dart';
import 'package:pointycastle/block/aes.dart';
import 'package:pointycastle/block/modes/gcm.dart';
import 'package:pointycastle/key_derivators/api.dart';
import 'package:pointycastle/key_derivators/argon2.dart';

/// Password sealing for the backup parts that carry credentials.
///
/// Key: Argon2id (64 MiB, 2 passes, 1 lane) over the password and a fresh
/// 32-byte salt per export. Cipher: AES-256-GCM, a fresh 96-bit nonce per
/// part, 128-bit tag. The envelope's own header (part name, KDF parameters,
/// salt) is the GCM associated data, so lowering the cost, swapping the salt
/// or moving a sealed part under another name all fail authentication.
/// Only the sealed part is at stake: a failure skips it and nothing else.
final class BackupSeal {
  BackupSeal._(this._key, this._salt);

  static const _tag = 'pilibroSealed';
  static const _memoryPowerOf2 = 16;
  static const _iterations = 2;

  final Uint8List _key;
  final Uint8List _salt;

  static final _random = Random.secure();

  static Uint8List _bytes(int n) =>
      Uint8List.fromList(List.generate(n, (_) => _random.nextInt(256)));

  // Pure Dart and memory-hard, so it runs off the UI isolate.
  static Future<Uint8List> _derive(
    String password,
    Uint8List salt,
    int memoryPowerOf2,
    int iterations,
  ) => Isolate.run(
    () => (Argon2BytesGenerator()..init(
          Argon2Parameters(
            Argon2Parameters.ARGON2_id,
            salt,
            desiredKeyLength: 32,
            iterations: iterations,
            memoryPowerOf2: memoryPowerOf2,
          ),
        ))
        .process(utf8.encode(password)),
  );

  static Future<BackupSeal> create(String password) async {
    final salt = _bytes(32);
    return BackupSeal._(
      await _derive(password, salt, _memoryPowerOf2, _iterations),
      salt,
    );
  }

  static Uint8List _aad(String part, int m, int t, String salt) =>
      utf8.encode('$_tag/1|$part|argon2id|$m|$t|1|$salt');

  static Uint8List _gcm(
    bool encrypt,
    Uint8List key,
    Uint8List iv,
    Uint8List aad,
    Uint8List data,
  ) => (GCMBlockCipher(AESEngine())
    ..init(encrypt, AEADParameters(KeyParameter(key), 128, iv, aad)))
      .process(data);

  Map<String, Object> seal(String part, Object? json) {
    final salt = base64.encode(_salt);
    final iv = _bytes(12);
    return {
      _tag: 1,
      'kdf': 'argon2id',
      'm': _memoryPowerOf2,
      't': _iterations,
      'salt': salt,
      'iv': base64.encode(iv),
      'ct': base64.encode(
        _gcm(
          true,
          _key,
          iv,
          _aad(part, _memoryPowerOf2, _iterations, salt),
          utf8.encode(jsonEncode(json)),
        ),
      ),
    };
  }

  static bool isSealed(Object? json) => json is Map && json[_tag] == 1;

  /// Throws when the password is wrong or the envelope was altered.
  static Future<Object?> open(String part, Map env, String password) async {
    final m = env['m'] as int, t = env['t'] as int, salt = env['salt'] as String;
    final key = await _derive(password, base64.decode(salt), m, t);
    return jsonDecode(
      utf8.decode(
        _gcm(
          false,
          key,
          base64.decode(env['iv'] as String),
          _aad(part, m, t, salt),
          base64.decode(env['ct'] as String),
        ),
      ),
    );
  }
}