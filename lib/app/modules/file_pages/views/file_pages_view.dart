import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:file_manager/file_manager.dart';
import 'package:file_managers/app/modules/utils.dart';
import 'package:flutter/material.dart';
import 'package:fuzzywuzzy/fuzzywuzzy.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:open_file_plus/open_file_plus.dart';

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

    final filemanagerController = FileManagerController();

    Future<void> createZipArchive() async {
      final entities = controller.selectedItem;
      final directoryPath = entities[0].parent.path;
      final zipFile = '$directoryPath/archive.zip';
      controller.isSelected.value = false;
      final encoder = ZipFileEncoder();
      encoder.create(zipFile);
      for (var entity in entities) {
        if (entity is File) {
          encoder.addFile(entity);
        } else if (entity is Directory) {
          encoder.addDirectory(entity);
        } else if (entity is ArchiveFile) {
          encoder.addArchiveFile(entity as ArchiveFile);
        }
      }
      encoder.close();
    }

    Future<void> delete() async {
      for (final FileSystemEntity entity in controller.selectedItem) {
        try {
          entity
              .delete(recursive: true)
              .then((value) => controller.isSelected.value = false);
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('failed to delete file')));
        }
      }
    }

    Future<void> copy() async {
      for (final FileSystemEntity file in controller.selectedItem) {
        await File(file.uri.path).copy(
            '${filemanagerController.getCurrentPath}/${FileManager.basename(file)}');
      }
      if (controller.operation.value != Operation.none) {
        controller.operation.value = Operation.none;
      }
    }

    Future<void> move() async {
      for (final FileSystemEntity file in controller.selectedItem) {
        await File(file.uri.path).copy(
            '${filemanagerController.getCurrentPath}/${FileManager.basename(file)}');
        await file.delete();
      }
      if (controller.operation.value != Operation.none) {
        controller.operation.value = Operation.none;
      }
    }

    Future<void> rename() async {
      final file = controller.selectedItem.first;
      final initialValue = FileManager.basename(file);
      final textController = TextEditingController();
      textController.text = initialValue;
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
                decoration: const InputDecoration(isDense: true),
                controller: textController,
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
                  file.renameSync('${file.parent.path}/${textController.text}');
                  FocusScope.of(context).unfocus();
                  Navigator.of(context).pop();
                  controller.selectedItem.clear();
                  controller.isSelected.value = false;
                },
                child: const Text('rename'))
          ],
        ),
      );
      textController.dispose();
    }

    Future<void> extractZipArchive() async {
      final entity = controller.selectedItem[0];
      final directoryPath = entity.parent.path;
      final baseName = FileManager.basename(entity, showFileExtension: false);
      final lastDot = baseName.indexOf('.');
      final directoryName =
          lastDot == -1 ? baseName : baseName.substring(0, lastDot);
      final directory = '$directoryPath/$directoryName';
      controller.isSelected.value = false;

      try {
        final bytedata = await File(entity.uri.path).readAsBytes();
        final decode = ZipDecoder();
        Archive archive = decode.decodeBytes(bytedata);
        for (final ArchiveFile file in archive) {
          if (file.isFile) {
            final data = file.content as List<int>;
            File(directory)
              ..createSync(recursive: true)
              ..writeAsBytesSync(data);
          } else {
            Directory(directory).createSync();
          }
        }
      } catch (e) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
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
                DateFormat.yMEd().format(snapshot.data!.modified),
                style: const TextStyle(color: Colors.grey),
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
          return Image.asset('assets/picture.png');
        } else if (supportedSoundExtensions.contains(fileExtension)) {
          return Image.asset('assets/music.png');
        } else if (supportedVideoExtensions.contains(fileExtension)) {
          return Image.asset('assets/video.png');
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
          controller.textEditingController.clear();
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
                                controller.textEditingController.clear();
                              },
                              icon: const Icon(Icons.close_rounded),
                            ),
                          ),
                        ),
                      ),
                      controller: controller.textEditingController,
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
                      onPressed: () {},
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
                      onSelected: (value) {
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
                              delete();
                            }
                          case 'rename':
                            {
                              rename();
                            }
                          case 'extract':
                            {
                              extractZipArchive();
                            }
                          case 'compress':
                            {
                              createZipArchive();
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
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: ListTile(
                          leading: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Obx(
                              () => controller.isSelected.value
                                  ? SizedBox(
                                      width: MediaQuery.of(context).size.width *
                                          0.2,
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
                                          leading(entity: entity),
                                        ],
                                      ),
                                    )
                                  : leading(entity: entity),
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
                                    controller.textEditingController.clear();
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
                                      if (FileManager.getFileExtension(
                                              entity) ==
                                          'zip') {
                                        controller.selectedItem.value = [
                                          entity
                                        ];
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
                        ),
                      );
                    }),
              );
            }),
        floatingActionButton: Obx(
          () => Visibility(
            visible: controller.isMovingOrCopying.value,
            child: FloatingActionButton(
              shape: const CircleBorder(),
              onPressed: () {
                controller.isMovingOrCopying.value = false;
                switch (controller.operation.value) {
                  case Operation.move:
                    move();
                    return;
                  case Operation.copy:
                    copy();
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
