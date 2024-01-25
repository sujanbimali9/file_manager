import 'dart:developer';
import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:file_manager/file_manager.dart';
import 'package:file_managers/app/modules/utils.dart';
import 'package:flutter/material.dart';
import 'package:fuzzywuzzy/fuzzywuzzy.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:open_file_plus/open_file_plus.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:path/path.dart';
import '../controllers/file_pages_controller.dart';

class FilePagesView extends StatefulWidget {
  const FilePagesView({super.key});

  @override
  State<FilePagesView> createState() => _FilePagesViewState();
}

class _FilePagesViewState extends State<FilePagesView> {
  @override
  Widget build(BuildContext context) {
    final controller = Get.put(FilePagesController());

    final textEditingController = TextEditingController();

    final filemanagerController = FileManagerController();

    Future<void> createZipArchive() async {
      final entities = controller.selectedItem;
      late final String zipFile = '${entities[0].path}.zip';

      final encoder = ZipFileEncoder();
      encoder.create(zipFile);
      log('message');
      for (var entity in entities) {
        if (entity is File) {
          encoder.addFile(
            entity,
          );
        } else if (entity is Directory) {
          encoder.addDirectory(entity, onProgress: (value) {});
        } else if (entity is ArchiveFile) {
          encoder.addArchiveFile(
            entity as ArchiveFile,
          );
        }
      }
      encoder.close();
      controller.selectedItem.clear();
      controller.isSelected.value = false;
    }

    Future<void> delete() async {
      for (final FileSystemEntity entity in controller.selectedItem) {
        try {
          if (await entity.exists()) {
            entity
                .delete(recursive: true)
                .then((value) => controller.isSelected.value = false);
          }
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('failed to delete file')));
        }
      }
    }

    Future<void> copy() async {
      for (final FileSystemEntity file in controller.selectedItem) {
        if (await file.exists()) {
          await File(file.path).copy(
              '${filemanagerController.getCurrentPath}/${FileManager.basename(file)}');
        }
        if (controller.operation.value != Operation.none) {
          controller.operation.value = Operation.none;
        }
      }
    }

    Future<void> move() async {
      for (final FileSystemEntity file in controller.selectedItem) {
        if (await file.exists()) {
          await File(file.path).copy(
              '${filemanagerController.getCurrentPath}/${FileManager.basename(file)}');
          await file.delete();
        }
        if (controller.operation.value != Operation.none) {
          controller.operation.value = Operation.none;
        }
      }
    }

    Future<void> rename() async {
      if (controller.selectedItem.isNotEmpty) {
        var text = 'renamed';
        final file = controller.selectedItem.first;
        final initialValue = basename(file.path);
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(initialValue),
                const Text(
                  'Enter new name:',
                  style: TextStyle(fontSize: 15, color: Colors.grey),
                ),
                TextFormField(
                  decoration: InputDecoration(
                      isDense: true,
                      errorText: text.isEmpty ? 'name can\'t be empty' : null),
                  initialValue: initialValue,
                  validator: (value) {
                    if (text.isEmpty) return 'name can\'t be empty';
                    return null;
                  },
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  onChanged: (value) => text = value,
                ),
              ],
            ),
            actions: [
              TextButton(
                child: const Text('cancel'),
                onPressed: () {
                  FocusScope.of(context).unfocus();
                  Navigator.of(context).pop();
                },
              ),
              TextButton(
                  onPressed: () {
                    if (text.isNotEmpty) {
                      file.renameSync('${file.parent.path}/$text');
                      FocusScope.of(context).unfocus();
                      Navigator.of(context).pop();

                      controller.isSelected.value = false;
                    }
                  },
                  child: const Text('rename'))
            ],
          ),
        );
      }
    }

    Future<void> extractZipArchive() async {
      final entity = controller.selectedItem[0];
      final path = entity.path;
      final directory = withoutExtension(path);
      controller.isSelected.value = false;
      final List<int> bytes = File(path).readAsBytesSync();
      final Archive archive = ZipDecoder().decodeBytes(bytes);
      for (final file in archive) {
        final filename = file.name;
        if (file.isFile) {
          final data = file.content as List<int>;
          File('$directory/$filename')
            ..createSync(recursive: true)
            ..writeAsBytesSync(data);
        } else {
          Directory('$directory/$filename').create(recursive: true);
        }
      }
    }

    void searchFile() {
      final List<FileSystemEntity> searchResult = [];
      late int compare;
      for (FileSystemEntity entity in controller.tempentities) {
        compare = ratio(FileManager.basename(entity).toLowerCase(),
            controller.searchData.value.toLowerCase());
        if (compare >= 60) {
          searchResult.add(entity);
        }
      }
      controller.entities.value = searchResult;
    }

    Widget subtitle({required FileSystemEntity entity}) {
      return FutureBuilder<FileStat>(
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            if (FileManager.isFile(entity)) {
              return Text(
                FileManager.formatBytes(snapshot.data!.size),
                style:
                    const TextStyle(color: Color.fromARGB(255, 153, 153, 153)),
              );
            }
          } else {
            return const Text('');
          }
          return const Text('');
        },
        future: entity.stat(),
      );
    }

    Widget? trailing({required FileSystemEntity entity}) {
      return FutureBuilder<FileStat>(
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            if (FileManager.isFile(entity)) {
              return Text(
                DateFormat.yMd().format(snapshot.data!.modified),
                style: const TextStyle(color: Colors.grey),
                overflow: TextOverflow.ellipsis,
              );
            }
          } else {
            return const Text('');
          }
          return const Text('');
        },
        future: entity.stat(),
      );
    }

    Widget leading({required FileSystemEntity entity}) {
      if (FileManager.isDirectory(entity)) {
        return Image.asset('assets/folder.png');
      } else if (FileManager.isFile(entity)) {
        String fileExtension =
            FileManager.getFileExtension(entity).toLowerCase();
        if (supportedDocumentExtensions.contains(fileExtension)) {
          if (fileExtension == 'txt') {
            return Image.asset('assets/txt-file.png');
          } else {
            return Image.asset('assets/google-docs.png');
          }
        } else if (supportedImageExtensions.contains(fileExtension)) {
          final file = File(entity.path);
          if (file.existsSync()) {
            try {
              return Image.file(
                file,
                filterQuality: FilterQuality.low,
                fit: BoxFit.contain,
              );
            } catch (e) {
              return Image.asset('assets/picture.png');
            }
          }
          return Image.asset('assets/picture.png');
        } else if (supportedSoundExtensions.contains(fileExtension)) {
          return Image.asset('assets/music.png');
        } else if (supportedVideoExtensions.contains(fileExtension)) {
          try {
            final uint8list = VideoThumbnail.thumbnailData(
              video: entity.uri.path,
              imageFormat: ImageFormat.JPEG,
              maxWidth: 128,
              quality: 25,
            );
            return FutureBuilder(
                future: uint8list,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting ||
                      snapshot.connectionState == ConnectionState.active) {
                    return Image.asset('assets/video.png');
                  } else if (snapshot.hasError) {
                    return Image.asset('assets/video_error.png');
                  } else if (snapshot.hasData) {
                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        Image.memory(
                          snapshot.data!,
                          filterQuality: FilterQuality.low,
                          fit: BoxFit.contain,
                        ),
                        Image.asset(
                          'assets/play_video.png',
                          height: 20,
                          color: Colors.white,
                        )
                      ],
                    );
                  } else {
                    return Image.asset('assets/video.png');
                  }
                });
          } catch (e) {
            return Image.asset('assets/video.png');
          }
        } else if (fileExtension == 'apk') {
          return Image.asset('assets/apk.png');
        } else if (fileExtension == 'zip' ||
            fileExtension == 'rar' ||
            fileExtension == '7z') {
          return Image.asset('assets/compressed.png');
        }
      }

      return Image.asset('assets/unknown.png');
    }

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (controller.isSearching.value) {
          controller.updateSearchData('');
          controller.isSearching.value = false;
          textEditingController.clear();
          controller.entities.value = controller.tempentities;
        } else if (controller.isSelected.value) {
          controller.isSelected.value = false;
          controller.selectedItem.clear();
        } else if (await filemanagerController.isRootDirectory()) {
          controller.currentDirectory.value = 'storage';

          if (Navigator.canPop(context)) {
            Navigator.pop(context);
          }
        } else {
          filemanagerController.goToParentDirectory();
          if (await filemanagerController.isRootDirectory()) {
            controller.currentDirectory.value = 'storage';
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(
            title: Obx(() => controller.isSearching.value
                ? SizedBox(
                    height: kToolbarHeight * 0.8,
                    child: TextField(
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.all(10),
                        isDense: true,
                        focusedBorder: const OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.black),
                          borderRadius: BorderRadius.all(
                            Radius.circular(10),
                          ),
                        ),
                        border: const OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.grey),
                          borderRadius: BorderRadius.all(
                            Radius.circular(10),
                          ),
                        ),
                        suffix: Obx(
                          () => Visibility(
                            visible: controller.searchData.value != '',
                            child: IconButton(
                              onPressed: () {
                                controller.isSearching.value = true;
                                controller.updateSearchData('');
                                textEditingController.clear();
                              },
                              icon: const Icon(Icons.close_rounded),
                            ),
                          ),
                        ),
                      ),
                      controller: textEditingController,
                      onChanged: (value) {
                        controller.updateSearchData(value);
                        searchFile();
                      },
                      onSubmitted: (value) {},
                    ),
                  )
                : Text(controller.currentDirectory.value)),
            leading: Obx(() => Visibility(
                  visible: controller.isMovingOrCopying.value,
                  child: IconButton(
                      onPressed: () {
                        controller.isMovingOrCopying.value = false;
                        if (controller.selectedItem.isNotEmpty) {
                          controller.selectedItem.clear();
                        }
                      },
                      icon: const Icon(Icons.cancel_outlined)),
                )),
            centerTitle: true,
            actions: [
              Obx(() => !controller.isSearching.value
                  ? PopupMenuButton(
                      onSelected: (value) {
                        switch (value) {
                          case 'name':
                            filemanagerController.sortBy(SortBy.name);
                          case 'date':
                            filemanagerController.sortBy(SortBy.date);
                          case 'size':
                            filemanagerController.sortBy(SortBy.size);
                          case 'type':
                            filemanagerController.sortBy(SortBy.type);
                        }
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(
                          value: 'name',
                          child: Text('name'),
                        ),
                        PopupMenuItem(
                          value: 'date',
                          child: Text('date'),
                        ),
                        PopupMenuItem(
                          value: 'size',
                          child: Text('size'),
                        ),
                        PopupMenuItem(
                          value: 'type',
                          child: Text('type'),
                        ),
                      ],
                      icon: Image.asset('assets/sort.png'),
                    )
                  : const SizedBox()),
              Obx(() => !controller.isSearching.value
                  ? IconButton(
                      onPressed: () {
                        controller.isSearching.value = true;
                      },
                      icon: const Icon(Icons.search))
                  : const SizedBox()),
              Obx(() => controller.isSelected.value
                  ? PopupMenuButton(
                      onSelected: (value) async {
                        switch (value) {
                          case 'copy':
                            {
                              controller.isMovingOrCopying.value = true;
                              controller.isSelected.value = false;
                              controller.operation.value = Operation.copy;
                            }
                          case 'cut':
                            {
                              controller.isMovingOrCopying.value = true;
                              controller.isSelected.value = false;
                              controller.operation.value = Operation.move;
                            }
                          case 'delete':
                            {
                              await delete();
                              controller.selectedItem.clear();
                            }
                          case 'rename':
                            {
                              await rename();
                              controller.selectedItem.clear();
                            }
                          case 'extract':
                            {
                              await extractZipArchive();
                              controller.selectedItem.clear();
                            }
                          case 'compress':
                            {
                              await createZipArchive();
                              controller.selectedItem.clear();
                            }
                        }
                      },
                      itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'copy',
                              child: PopUpWidgets(
                                image: 'assets/copy.png',
                                title: 'copy',
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'cut',
                              child: PopUpWidgets(
                                image: 'assets/cut.png',
                                title: 'cut',
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: PopUpWidgets(
                                image: 'assets/delete.png',
                                title: 'delete',
                              ),
                            ),
                            if (controller.selectedItem.length == 1)
                              const PopupMenuItem(
                                value: 'rename',
                                child: PopUpWidgets(
                                  image: 'assets/rename.png',
                                  title: 'rename',
                                ),
                              ),
                            if (controller.selectedItem.length == 1 &&
                                FileManager.isFile(
                                    controller.selectedItem[0]) &&
                                supportedArchiveExtensions.contains(
                                    FileManager.getFileExtension(
                                            controller.selectedItem[0])
                                        .toLowerCase()))
                              const PopupMenuItem(
                                value: 'extract',
                                child: PopUpWidgets(
                                  image: 'assets/extract.png',
                                  title: 'extract',
                                ),
                              ),
                            const PopupMenuItem(
                              value: 'compress',
                              child: PopUpWidgets(
                                image: 'assets/compress.png',
                                title: 'compress',
                              ),
                            ),
                          ])
                  : const SizedBox()),
            ]),
        body: FileManager(
            controller: filemanagerController,
            builder: (context, snapshot) {
              controller.entities.value = snapshot;
              if (!controller.isSearching.value) {
                controller.tempentities.value = snapshot;
              }
              return Obx(
                () => ListView.builder(
                    itemCount: controller.entities.length,
                    itemBuilder: (context, index) {
                      final FileSystemEntity entity =
                          controller.entities[index];
                      return ListTile(
                        leading: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 5),
                          child: Obx(
                            () => controller.isSelected.value
                                ? SizedBox(
                                    width:
                                        MediaQuery.of(context).size.width * 0.2,
                                    child: Row(
                                      children: [
                                        if (controller.isSelected.value)
                                          controller.selectedItem
                                                  .contains(entity)
                                              ? const Icon(
                                                  Icons.check_box_outlined,
                                                  color: Colors.blueAccent,
                                                )
                                              : const Icon(Icons
                                                  .check_box_outline_blank),
                                        SizedBox(
                                            width: 40,
                                            child: leading(entity: entity)),
                                      ],
                                    ),
                                  )
                                : SizedBox(
                                    width: 40, child: leading(entity: entity)),
                          ),
                        ),
                        title: Text(FileManager.basename(entity,
                            showFileExtension: true)),
                        trailing: trailing(entity: entity),
                        subtitle: subtitle(entity: entity),
                        onTap: controller.isMovingOrCopying.value
                            ? () {
                                if (entity is Directory) {
                                  filemanagerController.openDirectory(entity);
                                }
                              }
                            : () async {
                                if (controller.isSearching.value) {
                                  if (FileManager.isDirectory(entity) ||
                                      controller.searchData.value.isEmpty) {
                                    controller.isSearching.value = false;
                                  }
                                  controller.updateSearchData('');
                                  textEditingController.clear();
                                }
                                if (controller.isSelected.value) {
                                  if (controller.selectedItem
                                      .contains(entity)) {
                                    controller.selectedItem.remove(entity);
                                    if (controller.selectedItem.isEmpty &&
                                        controller.isSelected.value) {
                                      controller.isSelected.value = false;
                                    }
                                  } else {
                                    controller.selectedItem.add(entity);
                                  }
                                } else {
                                  if (entity is Directory) {
                                    try {
                                      filemanagerController
                                          .openDirectory(entity);
                                      controller.currentDirectory.value =
                                          'storage/${filemanagerController.getCurrentDirectory.path.substring(20)}';
                                    } catch (e) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(const SnackBar(
                                              content: Text(
                                                  'unable to open this directory')));
                                    }
                                  } else {
                                    if (FileManager.getFileExtension(entity) ==
                                        'zip') {
                                      controller.selectedItem.value = [entity];
                                      extractZipArchive();
                                      controller.selectedItem.remove(entity);
                                    } else {
                                      OpenFile.open(entity.path);
                                    }
                                  }
                                }
                              },
                        onLongPress: controller.isMovingOrCopying.value
                            ? null
                            : () {
                                controller.isSelected.value = true;
                                controller.selectedItem.add(entity);
                              },
                      );
                    }),
              );
            }),
        floatingActionButton: Obx(
          () => Visibility(
            visible: controller.isMovingOrCopying.value,
            child: FloatingActionButton(
              shape: const CircleBorder(),
              onPressed: () async {
                controller.isMovingOrCopying.value = false;
                switch (controller.operation.value) {
                  case Operation.move:
                    await move();
                    controller.selectedItem.clear();
                    return;
                  case Operation.copy:
                    await copy();
                    controller.selectedItem.clear();
                    return;
                  case Operation.none:
                    return;
                }
              },
              child: Image.asset(
                'assets/paste.png',
                height: 30,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class PopUpWidgets extends StatelessWidget {
  final String image;
  final String title;
  const PopUpWidgets({
    super.key,
    required this.image,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      children: [
        Image.asset(
          image,
          height: 20,
        ),
        Padding(
          padding: const EdgeInsets.only(left: 8.0),
          child: Text(title),
        ),
      ],
    );
  }
}
