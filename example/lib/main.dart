import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:hdrsdr/hdrsdr.dart';
import 'package:photo_manager/photo_manager.dart';

void main() => runApp(const App());

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: const HdrToSdrDemo(),
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.teal),
    );
  }
}

class HdrToSdrDemo extends StatefulWidget {
  const HdrToSdrDemo({super.key});

  @override
  State<HdrToSdrDemo> createState() => _HdrToSdrDemoState();
}

class _HdrToSdrDemoState extends State<HdrToSdrDemo> {
  Uint8List? _origBytes;
  Uint8List? _sdrBytes;
  double _split = 0.5;

  Future<void> _pick() async {
    // Navigate to the ImagePickerScreen and wait for a result
    final Uint8List? orgBytes = await Navigator.push<Uint8List>(
      context,
      MaterialPageRoute(builder: (_) => const ImagePickerScreen()),
    );
    if (orgBytes != null) {
      final sdrBytes = await HdrSdr.convert(orgBytes, quality: 85);
      if (mounted) {
        setState(() {
          _origBytes = orgBytes;
          _sdrBytes = sdrBytes;
          _split = 0.5;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('HDR → SDR (sRGB) 比較デモ'),
        actions: [
          IconButton(onPressed: _pick, icon: const Icon(Icons.photo_library)),
        ],
      ),
      body: _origBytes == null
          ? const Center(child: Text('上のアルバムボタンで画像を選択'))
          : Column(
              children: [
                Expanded(
                  child: _sdrBytes == null
                      ? Image.memory(_origBytes!, fit: BoxFit.contain)
                      : _SplitCompare(
                          left: Image.memory(_origBytes!, fit: BoxFit.contain),
                          right: Image.memory(_sdrBytes!, fit: BoxFit.contain),
                          split: _split,
                          onChanged: (v) => setState(() => _split = v),
                        ),
                ),
                if (_sdrBytes != null)
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Slider(
                      value: _split,
                      onChanged: (v) => setState(() => _split = v),
                      label: '比較: ${(_split * 100).round()}%',
                    ),
                  ),
              ],
            ),
    );
  }
}

/// 左(オリジナル)と右(SDR)をスライダーで比較表示する簡易ウィジェット
class _SplitCompare extends StatelessWidget {
  final Widget left;
  final Widget right;
  final double split; // 0..1
  final ValueChanged<double> onChanged;

  const _SplitCompare({
    required this.left,
    required this.right,
    required this.split,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final h = c.maxHeight;
        final cut = (w * split).clamp(0, w);
        return GestureDetector(
          onHorizontalDragUpdate: (d) {
            final nx = (cut + d.delta.dx).clamp(0, w) / w;
            onChanged(nx);
          },
          child: Stack(
            children: [
              Center(child: right),
              ClipRect(
                child: Align(
                  alignment: Alignment.centerLeft,
                  widthFactor: split,
                  child: SizedBox(width: w, height: h, child: left),
                ),
              ),
              Positioned(
                left: cut - 1,
                top: 0,
                bottom: 0,
                child: Container(width: 2, color: Colors.amber),
              ),
            ],
          ),
        );
      },
    );
  }
}

// --- New Image Picker Screen ---
class ImagePickerScreen extends StatefulWidget {
  const ImagePickerScreen({super.key});

  @override
  State<ImagePickerScreen> createState() => _ImagePickerScreenState();
}

class _ImagePickerScreenState extends State<ImagePickerScreen> {
  List<AssetPathEntity> _albums = [];
  List<AssetEntity> _photos = [];
  AssetPathEntity? _selectedAlbum;
  bool _isLoading = true;
  PermissionState _permissionState = PermissionState.notDetermined;

  @override
  void initState() {
    super.initState();
    _requestPermissionAndLoadAlbums();
  }

  Future<void> _requestPermissionAndLoadAlbums() async {
    setState(() => _isLoading = true);
    _permissionState = await PhotoManager.requestPermissionExtend();
    if (!mounted) return;

    if (_permissionState.isAuth) {
      final albums = await PhotoManager.getAssetPathList(
        type: RequestType.image,
      );
      if (!mounted) return;
      setState(() {
        _albums = albums;
        _isLoading = false;
      });
      if (_albums.isNotEmpty) {
        // Optionally, load photos from the first album automatically
        // _loadPhotos(_albums.first);
      }
    } else {
      setState(() => _isLoading = false);
      // Handle permission denied - user can be prompted to open settings
    }
  }

  Future<void> _loadPhotos(AssetPathEntity album) async {
    setState(() {
      _isLoading = true;
      _selectedAlbum = album;
      _photos = []; // Clear previous photos
    });
    // Load all photos in the album (or use pagination for very large albums)
    final photos = await album.getAssetListRange(
      start: 0,
      end: await album.assetCountAsync,
    );
    if (!mounted) return;
    setState(() {
      _photos = photos;
      _isLoading = false;
    });
  }

  void _onPhotoTapped(AssetEntity photo) async {
    final file = (await photo.originFile);

    final Uint8List? imageBytes = file?.readAsBytesSync();
    if (imageBytes != null && mounted) {
      Navigator.pop(context, imageBytes);
    } else {
      // Handle error loading image bytes
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not load image data.')),
      );
    }
  }

  Widget _buildAlbumList() {
    if (_albums.isEmpty) {
      return const Center(child: Text('No albums found.'));
    }
    return ListView.builder(
      itemCount: _albums.length,
      itemBuilder: (context, index) {
        final album = _albums[index];
        return ListTile(
          leading: FutureBuilder<int>(
            future: album.assetCountAsync,
            builder: (context, snapshot) {
              if (snapshot.hasData && snapshot.data! > 0) {
                // Display thumbnail of the first asset in the album
                return FutureBuilder<List<AssetEntity>>(
                  future: album.getAssetListRange(start: 0, end: 1),
                  builder: (context, assetSnapshot) {
                    if (assetSnapshot.hasData &&
                        assetSnapshot.data!.isNotEmpty) {
                      return SizedBox(
                        width: 50,
                        height: 50,
                        child: FutureBuilder(
                          future: assetSnapshot.data!.first.thumbnailData,
                          builder: (ctx, ss) {
                            if (!ss.hasData) return const SizedBox.shrink();
                            return Image.memory(ss.data!, fit: BoxFit.cover);
                          },
                        ),
                      );
                    }
                    return const SizedBox(
                      width: 50,
                      height: 50,
                      child: Icon(Icons.photo_album),
                    );
                  },
                );
              }
              return const SizedBox(
                width: 50,
                height: 50,
                child: Icon(Icons.photo_album),
              );
            },
          ),
          title: Text(album.name.isEmpty ? "Unknown Album" : album.name),
          subtitle: FutureBuilder<int>(
            future: album.assetCountAsync,
            builder: (context, snapshot) =>
                Text('${snapshot.data ?? 0} photos'),
          ),
          onTap: () => _loadPhotos(album),
        );
      },
    );
  }

  Widget _buildPhotoGrid() {
    if (_photos.isEmpty) {
      return const Center(child: Text('No photos in this album.'));
    }
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 4.0,
        mainAxisSpacing: 4.0,
      ),
      itemCount: _photos.length,
      itemBuilder: (context, index) {
        final photo = _photos[index];
        return GestureDetector(
          onTap: () => _onPhotoTapped(photo),
          child: FutureBuilder(
            future: photo.thumbnailData,
            builder: (ctx, ss) {
              if (!ss.hasData) return const SizedBox.shrink();
              return Image.memory(ss.data!, fit: BoxFit.cover);
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _selectedAlbum == null
              ? 'Select Album'
              : _selectedAlbum!.name.isEmpty
              ? "Unknown Album"
              : _selectedAlbum!.name,
        ),
        leading: _selectedAlbum != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  setState(() {
                    _selectedAlbum = null;
                    _photos = [];
                  });
                },
              )
            : null,
      ),
      body: Builder(
        builder: (context) {
          if (!_permissionState.isAuth && !_isLoading) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Photo library permission is required.'),
                  ElevatedButton(
                    onPressed: () async {
                      final granted =
                          await PhotoManager.requestPermissionExtend(
                            requestOption: const PermissionRequestOption(
                              iosAccessLevel: IosAccessLevel
                                  .readWrite, // Or .addOnly if sufficient
                            ),
                          );
                      if (granted.isAuth) {
                        _requestPermissionAndLoadAlbums();
                      } else {
                        // Optionally open app settings if permission is permanently denied
                        PhotoManager.openSetting();
                      }
                    },
                    child: const Text('Grant Permission'),
                  ),
                ],
              ),
            );
          }

          if (_isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          return _selectedAlbum == null ? _buildAlbumList() : _buildPhotoGrid();
        },
      ),
    );
  }
}
