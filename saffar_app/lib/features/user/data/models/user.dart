import 'package:saffar_app/core/utils/model_helper.dart';

/// User 
class User {
  const User({
    required this.id,
    required this.name,
    required this.phone,
    this.email,
    this.imageUrl,
  });

  final String id;
  final String name;
  final String phone;
  final String? email;
  final String? imageUrl;

  factory User.fromMap(Map<dynamic, dynamic> map) {
    ModelHelper.throwExceptionIfRequiredFieldsNotPresentInMap(
      'User',
      map,
      ['id', 'name', 'phone'],
    );

    return User(
      id: map['id'].toString(),
      name: map['name'].toString(),
      phone: map['phone'].toString(),
      email: map['email']?.toString(),
      imageUrl: (map['imageUrl'] ?? map['image_url'])?.toString(),
    );
  }

  Map<dynamic, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'email': email,
      'imageUrl': imageUrl,
      'image_url': imageUrl,
    };
  }
}
