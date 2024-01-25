import 'dart:io';
import 'package:get/get.dart';

class FilePagesController extends GetxController {
  // late FileManagerController fileManagerController;
  // late TextEditingController textEditingController;
  var isSelected = false.obs;
  var selectedItem = <FileSystemEntity>[].obs;
  late RxString currentDirectory = 'storage'.obs;
  var isSearching = false.obs;
  var entities = <FileSystemEntity>[].obs;
  var tempentities = <FileSystemEntity>[].obs;
  var searchData = ''.obs;
  var isMovingOrCopying = false.obs;
  void updateSearchData(String value) {
    searchData.value = value;
  }

  var operation = Operation.none.obs;

  @override
  void onInit() {
    // fileManagerController = FileManagerController();
    // textEditingController = TextEditingController();
    super.onInit();
  }

  @override
  void onClose() {
    // textEditingController.dispose();
    // fileManagerController.dispose();
    super.onClose();
  }
}

enum Operation { copy, move, none }
