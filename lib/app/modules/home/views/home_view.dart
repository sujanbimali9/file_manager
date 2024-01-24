import 'package:disk_space_update/disk_space_update.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/home_controller.dart';

class HomeView extends StatelessWidget {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(HomeController());
    Future<void> getDiskInfo() async {
      controller.freeSpace.value = await DiskSpace.getFreeDiskSpace ?? 0.0;
      controller.totalSpace.value = await DiskSpace.getTotalDiskSpace ?? 0.0;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('File Manager'),
        centerTitle: true,
        actions: [IconButton(onPressed: () {}, icon: const Icon(Icons.search))],
      ),
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.all(10),
            padding: const EdgeInsets.only(
              top: 20,
              right: 5,
              left: 5,
            ),
            decoration: const BoxDecoration(
                color: Color.fromARGB(255, 201, 201, 201),
                borderRadius: BorderRadius.all(Radius.circular(10))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(left: 10.0, bottom: 10),
                  child: Text(
                    'Categories',
                    style: TextStyle(fontSize: 20),
                  ),
                ),
                GridView(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    mainAxisExtent: 90,
                    crossAxisCount: 3,
                  ),
                  children: [
                    CatergoryCard(
                      image: 'assets/picture.png',
                      onPressed: () {},
                      title: 'Image',
                    ),
                    CatergoryCard(
                      image: 'assets/play.png',
                      onPressed: () {},
                      title: 'Video',
                    ),
                    CatergoryCard(
                      image: 'assets/music.png',
                      onPressed: () {},
                      title: 'Audio',
                    ),
                    CatergoryCard(
                      image: 'assets/google-docs.png',
                      onPressed: () {},
                      title: 'Documents',
                    ),
                    CatergoryCard(
                      image: 'assets/download.png',
                      onPressed: () {},
                      title: 'Downloads',
                    ),
                    CatergoryCard(
                      image: 'assets/apk.png',
                      onPressed: () {},
                      title: 'Installation files',
                    ),
                  ],
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () {
              Navigator.of(context).pushNamed('/file_view');
            },
            child: Container(
              margin: const EdgeInsets.all(10),
              padding: const EdgeInsets.all(5),
              decoration: const BoxDecoration(
                color: Color.fromARGB(255, 201, 201, 201),
                borderRadius: BorderRadius.all(
                  Radius.circular(10),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Image.asset(
                        'assets/ewallet.png',
                        height: 70,
                        width: 40,
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Internal storage'),
                            FutureBuilder(
                                future: getDiskInfo(),
                                builder: (context, snapshot) {
                                  return Text(
                                      '${controller.freeSpace.value}/${controller.totalSpace}');
                                }),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}

class CatergoryCard extends StatelessWidget {
  final String image;
  final String title;
  final VoidCallback onPressed;

  const CatergoryCard({
    super.key,
    required this.image,
    required this.title,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: const BorderRadius.all(Radius.circular(10)),
      onTap: onPressed,
      child: Padding(
        padding: const EdgeInsets.all(0.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Image.asset(
              image,
              height: 35,
            ),
            Text(title),
          ],
        ),
      ),
    );
  }
}
