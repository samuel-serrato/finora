// models/image_data.dart
class ImageData {
  final String tipoImagen;
  final String rutaImagen;

  ImageData({
    required this.tipoImagen,
    required this.rutaImagen,
  });

  factory ImageData.fromJson(Map<String, dynamic> json) {
    return ImageData(
      tipoImagen: json['tipoImagen'],
      rutaImagen: json['rutaImagen'],
    );
  }
}