import 'dart:io';
import 'package:flutter/material.dart';

class ImageSectionWidget extends StatelessWidget {
  final File? processedImage;
  final bool isProcessing;
  final VoidCallback onCropImagePressed;

  const ImageSectionWidget({
    super.key,
    required this.processedImage,
    required this.isProcessing,
    required this.onCropImagePressed,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Selected Image',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Container(
          height: 250,
          width: double.infinity,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: processedImage != null
                    ? Image.file(
                        processedImage!,
                        height: 250,
                        width: double.infinity,
                        fit: BoxFit.contain,
                      )
                    : Container(
                        color: Colors.grey[200],
                        child: const Icon(
                          Icons.image_not_supported,
                          size: 50,
                          color: Colors.grey,
                        ),
                      ),
              ),
              if (isProcessing)
                Container(
                  color: Colors.black.withOpacity(0.5),
                  child: const Center(
                    child: CircularProgressIndicator(),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: TextButton.icon(
            onPressed: onCropImagePressed,
            icon: const Icon(Icons.crop),
            label: const Text('Crop Image'),
          ),
        ),
      ],
    );
  }
}
