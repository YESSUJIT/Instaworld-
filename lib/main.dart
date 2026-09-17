import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';

import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const InstakiloApp());
}

class AppColors {
  static const Color pink = Color(0xFFE1306C);
  static const Color purple = Color(0xFF833AB4);
  static const Color orange = Color(0xFFF77737);
  static const Color yellow = Color(0xFFFCAF45);
}

class InstakiloApp extends StatefulWidget {
  const InstakiloApp({super.key});

  @override
  State<InstakiloApp> createState() => _InstakiloAppState();
}

class _InstakiloAppState extends State<InstakiloApp>
    with WidgetsBindingObserver {
  bool locked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    checkLock();
  }

  Future<void> checkLock() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool('profile_lock') ?? false;

    if (enabled && mounted) {
      setState(() {
        locked = true;
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      checkLock();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (locked) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: LockScreen(
          onUnlocked: () {
            setState(() {
              locked = false;
            });
          },
        ),
      );
    }

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Instakilo',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.white,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.pink,
        ),
      ),
      home: const MainNavigation(),
    );
  }
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int index = 0;

  final List<Widget> pages = const [
    HomePage(),
    SearchPage(),
    ReelsPage(),
    UploadPage(),
    ProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: index,
        children: pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (value) {
          setState(() {
            index = value;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: ImageIcon(
              AssetImage('assets/icons/home.png'),
            ),
            label: 'Home',
          ),
          NavigationDestination(
            icon: ImageIcon(
              AssetImage('assets/icons/search.png'),
            ),
            label: 'Search',
          ),
          NavigationDestination(
            icon: ImageIcon(
              AssetImage('assets/icons/reels.png'),
            ),
            label: 'Reels',
          ),
          NavigationDestination(
            icon: ImageIcon(
              AssetImage('assets/icons/upload.png'),
            ),
            label: 'Upload',
          ),
          NavigationDestination(
            icon: ImageIcon(
              AssetImage('assets/icons/profile.png'),
            ),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------
// FIREBASE HELPERS
// ------------------------------------------------------------

final FirebaseFirestore db = FirebaseFirestore.instance;
final FirebaseStorage storage = FirebaseStorage.instance;
final FirebaseAuth auth = FirebaseAuth.instance;

User? get currentUser => auth.currentUser;

String get currentUid => currentUser?.uid ?? '';

Future<String> uploadFile(
  File file,
  String folder,
) async {
  final name =
      '${DateTime.now().millisecondsSinceEpoch}_${file.path.split('/').last}';

  final ref = storage.ref().child(
        '$folder/$currentUid/$name',
      );

  final task = await ref.putFile(file);

  return await task.ref.getDownloadURL();
}

// ------------------------------------------------------------
// INSTAKILO LOGO
// ------------------------------------------------------------

class InstakiloLogo extends StatelessWidget {
  final double size;

  const InstakiloLogo({
    super.key,
    this.size = 25,
  });

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (bounds) {
        return const LinearGradient(
          colors: [
            AppColors.yellow,
            AppColors.orange,
            AppColors.pink,
            AppColors.purple,
          ],
        ).createShader(bounds);
      },
      child: Text(
        'INSTAKILO',
        style: TextStyle(
          color: Colors.white,
          fontSize: size,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

// ------------------------------------------------------------
// PNG BUTTON
// ------------------------------------------------------------

class PngButton extends StatelessWidget {
  final String asset;
  final VoidCallback onTap;
  final double size;

  const PngButton({
    super.key,
    required this.asset,
    required this.onTap,
    this.size = 27,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Image.asset(
          asset,
          width: size,
          height: size,
          errorBuilder: (_, __, ___) {
            return Icon(
              Icons.image_not_supported_outlined,
              size: size,
            );
          },
        ),
      ),
    );
  }
}

// ------------------------------------------------------------
// USER DATA
// ------------------------------------------------------------

class UserData {
  final String uid;
  final String username;
  final String name;
  final String photo;

  UserData({
    required this.uid,
    required this.username,
    required this.name,
    required this.photo,
  });

  factory UserData.fromMap(
    String uid,
    Map<String, dynamic> map,
  ) {
    return UserData(
      uid: uid,
      username: map['username'] ?? '',
      name: map['name'] ?? '',
      photo: map['photo'] ?? '',
    );
  }
}

Future<UserData?> getUserData(String uid) async {
  final snap = await db.collection('users').doc(uid).get();

  if (!snap.exists) {
    return null;
  }

  return UserData.fromMap(
    uid,
    snap.data() ?? {},
  );
}

// ------------------------------------------------------------
// HOME PAGE
// ------------------------------------------------------------

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const InstakiloLogo(
          size: 25,
        ),
        actions: [
          PngButton(
            asset: 'assets/icons/like.png',
            onTap: () {},
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(
              Icons.chat_bubble_outline,
            ),
          ),
        ],
      ),
      body: const Column(
        children: [
          StoriesBar(),
          Divider(height: 1),
          Expanded(
            child: FirebaseHomeFeed(),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------
// STORIES
// ------------------------------------------------------------

class StoriesBar extends StatelessWidget {
  const StoriesBar({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 105,
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: db
            .collection('users')
            .orderBy('username')
            .limit(30)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final users = snapshot.data!.docs;

          return ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 10,
            ),
            itemCount: users.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return const StoryCircle(
                  name: 'Your story',
                  image: '',
                );
              }

              final data = users[index - 1].data();

              return StoryCircle(
                name: data['username'] ?? 'user',
                image: data['photo'] ?? '',
              );
            },
          );
        },
      ),
    );
  }
}

class StoryCircle extends StatelessWidget {
  final String name;
  final String image;

  const StoryCircle({
    super.key,
    required this.name,
    required this.image,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 78,
      margin: const EdgeInsets.only(right: 8),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  AppColors.yellow,
                  AppColors.orange,
                  AppColors.pink,
                  AppColors.purple,
                ],
              ),
            ),
            child: CircleAvatar(
              radius: 29,
              backgroundColor: Colors.white,
              child: CircleAvatar(
                radius: 26,
                backgroundImage: image.isNotEmpty
                    ? NetworkImage(image)
                    : const AssetImage(
                            'assets/icons/app_icon.png')
                        as ImageProvider,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------
// FIREBASE HOME FEED
// ------------------------------------------------------------

class FirebaseHomeFeed extends StatelessWidget {
  const FirebaseHomeFeed({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: db
          .collection('posts')
          .orderBy(
            'createdAt',
            descending: true,
          )
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Feed error: ${snapshot.error}',
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        final posts = snapshot.data!.docs;

        if (posts.isEmpty) {
          return const Center(
            child: Text(
              'Abhi koi post nahi hai',
            ),
          );
        }

        return ListView.builder(
          itemCount: posts.length,
          itemBuilder: (context, index) {
            return PostCard(
              postId: posts[index].id,
              data: posts[index].data(),
            );
          },
        );
      },
    );
  }
}

// ------------------------------------------------------------
// POST CARD
// ------------------------------------------------------------

class PostCard extends StatefulWidget {
  final String postId;
  final Map<String, dynamic> data;

  const PostCard({
    super.key,
    required this.postId,
    required this.data,
  });

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  bool liked = false;
  bool saved = false;

  String get uid => widget.data['uid'] ?? '';

  String get mediaUrl => widget.data['mediaUrl'] ?? '';

  bool get isVideo => widget.data['type'] == 'video';

  @override
  void initState() {
    super.initState();
    checkLike();
    checkSave();
  }

  Future<void> checkLike() async {
    if (currentUid.isEmpty) return;

    final snap = await db
        .collection('posts')
        .doc(widget.postId)
        .collection('likes')
        .doc(currentUid)
        .get();

    if (mounted) {
      setState(() {
        liked = snap.exists;
      });
    }
  }

  Future<void> checkSave() async {
    if (currentUid.isEmpty) return;

    final snap = await db
        .collection('users')
        .doc(currentUid)
        .collection('saved')
        .doc(widget.postId)
        .get();

    if (mounted) {
      setState(() {
        saved = snap.exists;
      });
    }
  }

  Future<void> toggleLike() async {
    if (currentUid.isEmpty) return;

    final postRef =
        db.collection('posts').doc(widget.postId);

    final likeRef =
        postRef.collection('likes').doc(currentUid);

    if (liked) {
      await likeRef.delete();

      await postRef.update({
        'likesCount': FieldValue.increment(-1),
      });

      setState(() {
        liked = false;
      });
    } else {
      await likeRef.set({
        'uid': currentUid,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await postRef.update({
        'likesCount': FieldValue.increment(1),
      });

      setState(() {
        liked = true;
      });
    }
  }

  Future<void> toggleSave() async {
    if (currentUid.isEmpty) return;

    final ref = db
        .collection('users')
        .doc(currentUid)
        .collection('saved')
        .doc(widget.postId);

    if (saved) {
      await ref.delete();

      setState(() {
        saved = false;
      });
    } else {
      await ref.set({
        'postId': widget.postId,
        'createdAt': FieldValue.serverTimestamp(),
      });

      setState(() {
        saved = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final username = widget.data['username'] ?? 'user';
    final caption = widget.data['caption'] ?? '';
    final location = widget.data['location'] ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          leading: const CircleAvatar(
            backgroundImage:
                AssetImage('assets/icons/app_icon.png'),
          ),
          title: Text(
            username,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
          subtitle: location.toString().isNotEmpty
              ? Text(location)
              : null,
          trailing: IconButton(
            onPressed: () {},
            icon: const Icon(Icons.more_vert),
          ),
        ),

        if (mediaUrl.isNotEmpty)
          isVideo
              ? VideoPost(
                  url: mediaUrl,
                )
              : AspectRatio(
                  aspectRatio: 1,
                  child: Image.network(
                    mediaUrl,
                    fit: BoxFit.cover,
                    loadingBuilder:
                        (context, child, progress) {
                      if (progress == null) {
                        return child;
                      }

                      return const Center(
                        child: CircularProgressIndicator(),
                      );
                    },
                  ),
                ),

        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 5,
          ),
          child: Row(
            children: [
              PngButton(
                asset: 'assets/icons/like.png',
                size: 27,
                onTap: toggleLike,
              ),
              PngButton(
                asset: 'assets/icons/comment.png',
                size: 27,
                onTap: () {
                  showComments(
                    context,
                    widget.postId,
                  );
                },
              ),
              PngButton(
                asset: 'assets/icons/share.png',
                size: 27,
                onTap: () {
                  sharePost(context);
                },
              ),
              const Spacer(),
              PngButton(
                asset: 'assets/icons/save.png',
                size: 27,
                onTap: toggleSave,
              ),
            ],
          ),
        ),

        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
          ),
          child: Text(
            '${widget.data['likesCount'] ?? 0} likes',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),

        if (caption.toString().isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              12,
              5,
              12,
              14,
            ),
            child: RichText(
              text: TextSpan(
                style: const TextStyle(
                  color: Colors.black,
                ),
                children: [
                  TextSpan(
                    text: '$username ',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextSpan(
                    text: caption,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

// ------------------------------------------------------------
// VIDEO POST
// ------------------------------------------------------------

class VideoPost extends StatefulWidget {
  final String url;

  const VideoPost({
    super.key,
    required this.url,
  });

  @override
  State<VideoPost> createState() => _VideoPostState();
}

class _VideoPostState extends State<VideoPost> {
  late VideoPlayerController controller;

  @override
  void initState() {
    super.initState();

    controller = VideoPlayerController.networkUrl(
      Uri.parse(widget.url),
    )
      ..initialize().then((_) {
        if (mounted) {
          setState(() {});
        }
      })
      ..setLooping(true);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!controller.value.isInitialized) {
      return const AspectRatio(
        aspectRatio: 1,
        child: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return GestureDetector(
      onTap: () {
        setState(() {
          if (controller.value.isPlaying) {
            controller.pause();
          } else {
            controller.play();
          }
        });
      },
      child: AspectRatio(
        aspectRatio: controller.value.aspectRatio,
        child: VideoPlayer(controller),
      ),
    );
  }
}
//
// ============================================================
// PART 2/5
// COMMENTS + SHARE + REELS
// ============================================================

// ------------------------------------------------------------
// COMMENTS
// ------------------------------------------------------------

void showComments(
  BuildContext context,
  String postId,
) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    builder: (context) {
      return CommentsSheet(
        postId: postId,
      );
    },
  );
}

class CommentsSheet extends StatefulWidget {
  final String postId;

  const CommentsSheet({
    super.key,
    required this.postId,
  });

  @override
  State<CommentsSheet> createState() =>
      _CommentsSheetState();
}

class _CommentsSheetState extends State<CommentsSheet> {
  final TextEditingController controller =
      TextEditingController();

  bool sending = false;

  Future<void> sendComment() async {
    final text = controller.text.trim();

    if (text.isEmpty) return;
    if (currentUid.isEmpty) return;

    setState(() {
      sending = true;
    });

    final user = await getUserData(currentUid);

    await db
        .collection('posts')
        .doc(widget.postId)
        .collection('comments')
        .add({
      'uid': currentUid,
      'username': user?.username ?? 'user',
      'photo': user?.photo ?? '',
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await db
        .collection('posts')
        .doc(widget.postId)
        .update({
      'commentsCount': FieldValue.increment(1),
    });

    controller.clear();

    if (mounted) {
      setState(() {
        sending = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * .75,
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(15),
              child: Text(
                'Comments',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            const Divider(height: 1),

            Expanded(
              child: StreamBuilder<
                  QuerySnapshot<Map<String, dynamic>>>(
                stream: db
                    .collection('posts')
                    .doc(widget.postId)
                    .collection('comments')
                    .orderBy(
                      'createdAt',
                      descending: false,
                    )
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Comments error: ${snapshot.error}',
                      ),
                    );
                  }

                  if (!snapshot.hasData) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }

                  final comments = snapshot.data!.docs;

                  if (comments.isEmpty) {
                    return const Center(
                      child: Text(
                        'No comments yet',
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: comments.length,
                    itemBuilder: (context, index) {
                      final data =
                          comments[index].data();

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundImage:
                              data['photo']
                                          ?.toString()
                                          .isNotEmpty ==
                                      true
                                  ? NetworkImage(
                                      data['photo'],
                                    )
                                  : const AssetImage(
                                      'assets/icons/app_icon.png',
                                    ) as ImageProvider,
                        ),
                        title: Text(
                          data['username'] ?? 'user',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(
                          data['text'] ?? '',
                        ),
                      );
                    },
                  );
                },
              ),
            ),

            const Divider(height: 1),

            Padding(
              padding: EdgeInsets.only(
                left: 10,
                right: 10,
                top: 8,
                bottom: MediaQuery.of(context)
                        .viewInsets
                        .bottom +
                    8,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      decoration: InputDecoration(
                        hintText: 'Add a comment...',
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(25),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed:
                        sending ? null : sendComment,
                    icon: sending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child:
                                CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(
                            Icons.send,
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}

// ------------------------------------------------------------
// SHARE
// ------------------------------------------------------------

void sharePost(
  BuildContext context,
) {
  showModalBottomSheet(
    context: context,
    builder: (context) {
      return SafeArea(
        child: Wrap(
          children: [
            const Padding(
              padding: EdgeInsets.all(18),
              child: Text(
                'Share',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.send),
              title: const Text('Share with user'),
              onTap: () {
                Navigator.pop(context);

                ScaffoldMessenger.of(context)
                    .showSnackBar(
                  const SnackBar(
                    content: Text(
                      'User sharing screen open hoga',
                    ),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.link),
              title: const Text('Copy link'),
              onTap: () {
                Navigator.pop(context);

                ScaffoldMessenger.of(context)
                    .showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Post link copied',
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      );
    },
  );
}

// ------------------------------------------------------------
// REELS PAGE
// ------------------------------------------------------------

class ReelsPage extends StatefulWidget {
  const ReelsPage({super.key});

  @override
  State<ReelsPage> createState() =>
      _ReelsPageState();
}

class _ReelsPageState extends State<ReelsPage> {
  final PageController pageController =
      PageController();

  int currentReel = 0;

  @override
  void dispose() {
    pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: StreamBuilder<
          QuerySnapshot<Map<String, dynamic>>>(
        stream: db
            .collection('reels')
            .orderBy(
              'createdAt',
              descending: true,
            )
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Reels error: ${snapshot.error}',
                style: const TextStyle(
                  color: Colors.white,
                ),
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final reels = snapshot.data!.docs;

          if (reels.isEmpty) {
            return const Center(
              child: Text(
                'Abhi koi reel nahi hai',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                ),
              ),
            );
          }

          return Stack(
            children: [
              PageView.builder(
                controller: pageController,
                scrollDirection: Axis.vertical,
                itemCount: reels.length,
                onPageChanged: (index) {
                  setState(() {
                    currentReel = index;
                  });
                },
                itemBuilder: (context, index) {
                  return ReelItem(
                    reelId: reels[index].id,
                    data: reels[index].data(),
                  );
                },
              ),

              // TOP BAR
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    15,
                    10,
                    15,
                    0,
                  ),
                  child: Row(
                    children: [
                      const Text(
                        'Reels',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${currentReel + 1}/${reels.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ------------------------------------------------------------
// SINGLE REEL
// ------------------------------------------------------------

class ReelItem extends StatefulWidget {
  final String reelId;
  final Map<String, dynamic> data;

  const ReelItem({
    super.key,
    required this.reelId,
    required this.data,
  });

  @override
  State<ReelItem> createState() =>
      _ReelItemState();
}

class _ReelItemState extends State<ReelItem> {
  VideoPlayerController? controller;

  bool liked = false;
  bool saved = false;

  String get videoUrl =>
      widget.data['videoUrl'] ??
      widget.data['mediaUrl'] ??
      '';

  @override
  void initState() {
    super.initState();

    if (videoUrl.isNotEmpty) {
      controller =
          VideoPlayerController.networkUrl(
        Uri.parse(videoUrl),
      );

      controller!.initialize().then((_) {
        if (mounted) {
          setState(() {});
          controller!.setLooping(true);
          controller!.play();
        }
      });
    }

    checkLike();
    checkSave();
  }

  Future<void> checkLike() async {
    if (currentUid.isEmpty) return;

    final snap = await db
        .collection('reels')
        .doc(widget.reelId)
        .collection('likes')
        .doc(currentUid)
        .get();

    if (mounted) {
      setState(() {
        liked = snap.exists;
      });
    }
  }

  Future<void> checkSave() async {
    if (currentUid.isEmpty) return;

    final snap = await db
        .collection('users')
        .doc(currentUid)
        .collection('savedReels')
        .doc(widget.reelId)
        .get();

    if (mounted) {
      setState(() {
        saved = snap.exists;
      });
    }
  }

  Future<void> toggleLike() async {
    if (currentUid.isEmpty) return;

    final reelRef =
        db.collection('reels').doc(widget.reelId);

    final likeRef = reelRef
        .collection('likes')
        .doc(currentUid);

    if (liked) {
      await likeRef.delete();

      await reelRef.update({
        'likesCount': FieldValue.increment(-1),
      });

      setState(() {
        liked = false;
      });
    } else {
      await likeRef.set({
        'uid': currentUid,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await reelRef.update({
        'likesCount': FieldValue.increment(1),
      });

      setState(() {
        liked = true;
      });
    }
  }

  Future<void> toggleSave() async {
    if (currentUid.isEmpty) return;

    final ref = db
        .collection('users')
        .doc(currentUid)
        .collection('savedReels')
        .doc(widget.reelId);

    if (saved) {
      await ref.delete();

      setState(() {
        saved = false;
      });
    } else {
      await ref.set({
        'reelId': widget.reelId,
        'createdAt': FieldValue.serverTimestamp(),
      });

      setState(() {
        saved = true;
      });
    }
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final username =
        widget.data['username'] ?? 'user';

    final caption =
        widget.data['caption'] ?? '';

    return Stack(
      fit: StackFit.expand,
      children: [

        // VIDEO
        GestureDetector(
          onTap: () {
            if (controller == null) return;

            setState(() {
              if (controller!.value.isPlaying) {
                controller!.pause();
              } else {
                controller!.play();
              }
            });
          },
          child: controller != null &&
                  controller!.value.isInitialized
              ? FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width:
                        controller!.value.size.width,
                    height:
                        controller!.value.size.height,
                    child: VideoPlayer(controller!),
                  ),
                )
              : const Center(
                  child: CircularProgressIndicator(
                    color: Colors.white,
                  ),
                ),
        ),

        // DARK GRADIENT AT BOTTOM
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: 260,
          child: IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(.75),
                  ],
                ),
              ),
            ),
          ),
        ),

        // RIGHT ACTIONS
        Positioned(
          right: 12,
          bottom: 100,
          child: Column(
            children: [

              PngButton(
                asset: 'assets/icons/like.png',
                size: 34,
                onTap: toggleLike,
              ),

              Text(
                '${widget.data['likesCount'] ?? 0}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 18),

              PngButton(
                asset: 'assets/icons/comment.png',
                size: 34,
                onTap: () {
                  showComments(
                    context,
                    widget.reelId,
                  );
                },
              ),

              Text(
                '${widget.data['commentsCount'] ?? 0}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 18),

              PngButton(
                asset: 'assets/icons/share.png',
                size: 34,
                onTap: () {
                  sharePost(context);
                },
              ),

              const SizedBox(height: 18),

              PngButton(
                asset: 'assets/icons/save.png',
                size: 34,
                onTap: toggleSave,
              ),
            ],
          ),
        ),

        // USER + CAPTION
        Positioned(
          left: 15,
          right: 75,
          bottom: 30,
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                '@$username',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                caption,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
//
// ============================================================
// PART 3/5
// REAL GALLERY UPLOAD + POST/REEL SETTINGS + FIREBASE STORAGE
// ============================================================

// ------------------------------------------------------------
// UPLOAD PAGE
// ------------------------------------------------------------

class UploadPage extends StatefulWidget {
  const UploadPage({super.key});

  @override
  State<UploadPage> createState() => _UploadPageState();
}

class _UploadPageState extends State<UploadPage> {
  final ImagePicker picker = ImagePicker();

  File? selectedFile;
  bool isVideo = false;

  final TextEditingController captionController =
      TextEditingController();

  final TextEditingController locationController =
      TextEditingController();

  bool hideComments = false;
  bool notSeen = false;
  bool uploading = false;

  double uploadProgress = 0;

  List<String> hiddenUsers = [];

  Future<void> pickFromGallery() async {
    final XFile? file = await picker.pickMedia();

    if (file == null) return;

    final extension =
        file.path.toLowerCase();

    final video =
        extension.endsWith('.mp4') ||
        extension.endsWith('.mov') ||
        extension.endsWith('.avi') ||
        extension.endsWith('.mkv') ||
        extension.endsWith('.webm');

    setState(() {
      selectedFile = File(file.path);
      isVideo = video;
    });
  }

  Future<void> chooseLocation() async {
    final controller =
        TextEditingController(
      text: locationController.text,
    );

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            'Post location',
          ),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText:
                  'City, Country',
              prefixIcon:
                  Icon(Icons.location_on_outlined),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text(
                'Cancel',
              ),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  locationController.text =
                      controller.text.trim();
                });

                Navigator.pop(context);
              },
              child: const Text(
                'Save',
              ),
            ),
          ],
        );
      },
    );

    controller.dispose();
  }

  Future<void> chooseHiddenUsers() async {
    if (currentUid.isEmpty) {
      showMessage(
        'Pehle login karo',
      );
      return;
    }

    final snapshot = await db
        .collection('users')
        .orderBy('username')
        .limit(100)
        .get();

    final users = snapshot.docs
        .where(
          (doc) => doc.id != currentUid,
        )
        .toList();

    if (!mounted) return;

    final result =
        await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        final selected =
            Set<String>.from(hiddenUsers);

        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: SizedBox(
                height:
                    MediaQuery.of(context)
                            .size
                            .height *
                        .75,
                child: Column(
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'Hide from users',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
                    ),

                    const Divider(),

                    Expanded(
                      child: ListView.builder(
                        itemCount: users.length,
                        itemBuilder:
                            (context, index) {
                          final data =
                              users[index].data();

                          final uid =
                              users[index].id;

                          final username =
                              data['username'] ??
                                  'user';

                          final photo =
                              data['photo'] ??
                                  '';

                          final checked =
                              selected
                                  .contains(uid);

                          return CheckboxListTile(
                            value: checked,
                            onChanged: (value) {
                              setSheetState(() {
                                if (value == true) {
                                  selected.add(uid);
                                } else {
                                  selected.remove(uid);
                                }
                              });
                            },
                            secondary:
                                CircleAvatar(
                              backgroundImage:
                                  photo
                                          .toString()
                                          .isNotEmpty
                                      ? NetworkImage(
                                          photo,
                                        )
                                      : const AssetImage(
                                          'assets/icons/app_icon.png',
                                        ) as ImageProvider,
                            ),
                            title: Text(
                              '@$username',
                            ),
                          );
                        },
                      ),
                    ),

                    Padding(
                      padding:
                          const EdgeInsets.all(15),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(
                              context,
                              selected.toList(),
                            );
                          },
                          child: const Text(
                            'Done',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (result != null) {
      setState(() {
        hiddenUsers = result;
      });
    }
  }

  Future<String> uploadFileWithProgress(
    File file,
    String folder,
  ) async {
    final fileName =
        '${DateTime.now().millisecondsSinceEpoch}_${file.path.split('/').last}';

    final ref = storage
        .ref()
        .child(folder)
        .child(currentUid)
        .child(fileName);

    final uploadTask =
        ref.putFile(file);

    uploadTask.snapshotEvents.listen(
      (snapshot) {
        if (!mounted) return;

        if (snapshot.totalBytes > 0) {
          setState(() {
            uploadProgress =
                snapshot.bytesTransferred /
                    snapshot.totalBytes;
          });
        }
      },
    );

    final snapshot =
        await uploadTask;

    return await snapshot.ref
        .getDownloadURL();
  }

  Future<void> uploadPost() async {
    if (currentUid.isEmpty) {
      showMessage(
        'Login required',
      );
      return;
    }

    if (selectedFile == null) {
      showMessage(
        'Pehle photo ya video select karo',
      );
      return;
    }

    if (uploading) return;

    setState(() {
      uploading = true;
      uploadProgress = 0;
    });

    try {
      final user =
          await getUserData(currentUid);

      final username =
          user?.username ?? 'user';

      final caption =
          captionController.text.trim();

      final location =
          locationController.text.trim();

      // ------------------------------------------------------
      // VIDEO = REEL
      // ------------------------------------------------------

      if (isVideo) {
        final videoUrl =
            await uploadFileWithProgress(
          selectedFile!,
          'reels',
        );

        await db.collection('reels').add({
          'uid': currentUid,
          'username': username,
          'videoUrl': videoUrl,
          'mediaUrl': videoUrl,
          'caption': caption,
          'location': location,
          'hideComments': hideComments,
          'notSeen': notSeen,
          'hiddenUsers': hiddenUsers,
          'likesCount': 0,
          'commentsCount': 0,
          'sharesCount': 0,
          'createdAt':
              FieldValue.serverTimestamp(),
        });
      }

      // ------------------------------------------------------
      // PHOTO = POST
      // ------------------------------------------------------

      else {
        final imageUrl =
            await uploadFileWithProgress(
          selectedFile!,
          'posts',
        );

        await db.collection('posts').add({
          'uid': currentUid,
          'username': username,
          'mediaUrl': imageUrl,
          'type': 'image',
          'caption': caption,
          'location': location,
          'hideComments': hideComments,
          'notSeen': notSeen,
          'hiddenUsers': hiddenUsers,
          'likesCount': 0,
          'commentsCount': 0,
          'sharesCount': 0,
          'createdAt':
              FieldValue.serverTimestamp(),
        });
      }

      if (!mounted) return;

      setState(() {
        selectedFile = null;
        captionController.clear();
        locationController.clear();
        hiddenUsers.clear();
        hideComments = false;
        notSeen = false;
        uploadProgress = 1;
      });

      showMessage(
        'Upload complete ✓',
      );
    } catch (e) {
      showMessage(
        'Upload failed: $e',
      );
    } finally {
      if (mounted) {
        setState(() {
          uploading = false;
        });
      }
    }
  }

  void showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Create',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          if (selectedFile != null)
            TextButton(
              onPressed:
                  uploading ? null : uploadPost,
              child: const Text(
                'Upload',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [

            // ------------------------------------------------
            // GALLERY BUTTON
            // ------------------------------------------------

            if (selectedFile == null)
              Center(
                child: Column(
                  children: [
                    const SizedBox(height: 60),

                    Image.asset(
                      'assets/icons/upload.png',
                      width: 70,
                      height: 70,
                    ),

                    const SizedBox(height: 20),

                    const Text(
                      'Photo ya Reel upload karo',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 20),

                    ElevatedButton.icon(
                      onPressed:
                          pickFromGallery,
                      icon: const Icon(
                        Icons.photo_library_outlined,
                      ),
                      label: const Text(
                        'Open Gallery',
                      ),
                    ),
                  ],
                ),
              ),

            // ------------------------------------------------
            // SELECTED MEDIA
            // ------------------------------------------------

            if (selectedFile != null) ...[
              ClipRRect(
                borderRadius:
                    BorderRadius.circular(12),
                child: isVideo
                    ? Container(
                        height: 350,
                        width: double.infinity,
                        color: Colors.black,
                        child: const Center(
                          child: Icon(
                            Icons.play_circle,
                            color: Colors.white,
                            size: 70,
                          ),
                        ),
                      )
                    : Image.file(
                        selectedFile!,
                        height: 350,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
              ),

              const SizedBox(height: 15),

              // ------------------------------------------------
              // CAPTION
              // ------------------------------------------------

              TextField(
                controller:
                    captionController,
                maxLines: 5,
                decoration:
                    InputDecoration(
                  hintText:
                      'Write a caption...',
                  border:
                      OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(
                      12,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // ------------------------------------------------
              // LOCATION
              // ------------------------------------------------

              ListTile(
                contentPadding:
                    EdgeInsets.zero,
                leading: const Icon(
                  Icons.location_on_outlined,
                ),
                title: Text(
                  locationController.text
                          .isEmpty
                      ? 'Add location'
                      : locationController
                          .text,
                ),
                trailing: const Icon(
                  Icons.chevron_right,
                ),
                onTap: chooseLocation,
              ),

              const Divider(),

              // ------------------------------------------------
              // HIDE COMMENTS
              // ------------------------------------------------

              SwitchListTile(
                contentPadding:
                    EdgeInsets.zero,
                title: const Text(
                  'Hide comments',
                ),
                subtitle: const Text(
                  'Log comment nahi kar sakenge',
                ),
                value: hideComments,
                onChanged: (value) {
                  setState(() {
                    hideComments = value;
                  });
                },
              ),

              // ------------------------------------------------
              // NOT SEEN
              // ------------------------------------------------

              SwitchListTile(
                contentPadding:
                    EdgeInsets.zero,
                title: const Text(
                  'Not Seen',
                ),
                subtitle: const Text(
                  'Post/reel ko selected users se hide karein',
                ),
                value: notSeen,
                onChanged: (value) {
                  setState(() {
                    notSeen = value;
                  });
                },
              ),

              if (notSeen)
                ListTile(
                  contentPadding:
                      EdgeInsets.zero,
                  leading: const Icon(
                    Icons.person_off_outlined,
                  ),
                  title: const Text(
                    'Hide from users',
                  ),
                  subtitle: Text(
                    hiddenUsers.isEmpty
                        ? 'Kisi user ko select nahi kiya'
                        : '${hiddenUsers.length} user selected',
                  ),
                  trailing:
                      const Icon(
                    Icons.chevron_right,
                  ),
                  onTap:
                      chooseHiddenUsers,
                ),

              const SizedBox(height: 15),

              // ------------------------------------------------
              // UPLOAD BUTTON
              // ------------------------------------------------

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed:
                      uploading
                          ? null
                          : uploadPost,
                  child: uploading
                      ? Row(
                          mainAxisAlignment:
                              MainAxisAlignment
                                  .center,
                          children: [
                            const SizedBox(
                              width: 22,
                              height: 22,
                              child:
                                  CircularProgressIndicator(
                                strokeWidth: 2,
                                color:
                                    Colors.white,
                              ),
                            ),
                            const SizedBox(
                              width: 12,
                            ),
                            Text(
                              'Uploading ${(uploadProgress * 100).toInt()}%',
                            ),
                          ],
                        )
                      : const Text(
                          'Upload',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 30),
            ],
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    captionController.dispose();
    locationController.dispose();
    super.dispose();
  }
}
// ==============================
// PART 4/5 - SEARCH + PROFILE
// ==============================

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController searchController = TextEditingController();
  String searchText = '';

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> searchUsers() {
    if (searchText.trim().isEmpty) {
      return db
          .collection('users')
          .orderBy('username')
          .limit(30)
          .snapshots();
    }

    final text = searchText.trim();

    return db
        .collection('users')
        .orderBy('username')
        .startAt([text])
        .endAt(['$text\uf8ff'])
        .limit(30)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: searchController,
              decoration: InputDecoration(
                hintText: 'Search username',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    searchController.clear();
                    setState(() {
                      searchText = '';
                    });
                  },
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onChanged: (value) {
                setState(() {
                  searchText = value.toLowerCase();
                });
              },
            ),
          ),

          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: searchUsers(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text('Search error: ${snapshot.error}'),
                  );
                }

                final users = snapshot.data?.docs ?? [];

                if (users.isEmpty) {
                  return const Center(
                    child: Text('No users found'),
                  );
                }

                return ListView.builder(
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final doc = users[index];
                    final data = doc.data();

                    final uid = doc.id;
                    final username =
                        data['username']?.toString() ?? 'User';
                    final name =
                        data['name']?.toString() ?? '';
                    final photo =
                        data['photo']?.toString() ?? '';

                    if (uid == currentUid) {
                      return UserSearchTile(
                        uid: uid,
                        username: username,
                        name: name,
                        photo: photo,
                        showYou: true,
                      );
                    }

                    return UserSearchTile(
                      uid: uid,
                      username: username,
                      name: name,
                      photo: photo,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}


// ==============================
// USER SEARCH TILE
// ==============================

class UserSearchTile extends StatelessWidget {
  final String uid;
  final String username;
  final String name;
  final String photo;
  final bool showYou;

  const UserSearchTile({
    super.key,
    required this.uid,
    required this.username,
    required this.name,
    required this.photo,
    this.showYou = false,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        radius: 25,
        backgroundImage:
            photo.isNotEmpty ? NetworkImage(photo) : null,
        child: photo.isEmpty
            ? const Icon(Icons.person)
            : null,
      ),
      title: Text(
        username,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
        ),
      ),
      subtitle: Text(
        name.isEmpty ? (showYou ? 'You' : '') : name,
      ),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => UserProfilePage(uid: uid),
          ),
        );
      },
    );
  }
}


// ==============================
// PROFILE PAGE
// ==============================

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  @override
  Widget build(BuildContext context) {
    if (currentUid == null) {
      return const Scaffold(
        body: Center(
          child: Text('Please login first'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () {
              showProfileMenu(context);
            },
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: db.collection('users').doc(currentUid).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final data = snapshot.data?.data() ?? {};

          return SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 20),

                CircleAvatar(
                  radius: 52,
                  backgroundImage:
                      data['photo'] != null &&
                              data['photo'].toString().isNotEmpty
                          ? NetworkImage(data['photo'])
                          : null,
                  child: data['photo'] == null ||
                          data['photo'].toString().isEmpty
                      ? const Icon(
                          Icons.person,
                          size: 50,
                        )
                      : null,
                ),

                const SizedBox(height: 12),

                Text(
                  data['username']?.toString() ?? 'username',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                if (data['name'] != null)
                  Text(
                    data['name'].toString(),
                    style: const TextStyle(
                      color: Colors.grey,
                    ),
                  ),

                const SizedBox(height: 15),

                Row(
                  mainAxisAlignment:
                      MainAxisAlignment.spaceEvenly,
                  children: [
                    ProfileCount(
                      title: 'Posts',
                      count:
                          data['postsCount']?.toString() ?? '0',
                    ),
                    ProfileCount(
                      title: 'Followers',
                      count:
                          data['followersCount']?.toString() ?? '0',
                    ),
                    ProfileCount(
                      title: 'Following',
                      count:
                          data['followingCount']?.toString() ?? '0',
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                if (data['bio'] != null &&
                    data['bio'].toString().isNotEmpty)
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      data['bio'].toString(),
                      textAlign: TextAlign.center,
                    ),
                  ),

                const SizedBox(height: 20),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  EditProfilePage(data: data),
                            ),
                          );
                        },
                        child: const Text('Edit Profile'),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                const Divider(),

                const SizedBox(height: 20),

                const Text(
                  'Your Posts',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 10),

                UserPostsGrid(uid: currentUid!),
              ],
            ),
          );
        },
      ),
    );
  }
}


// ==============================
// PROFILE COUNT
// ==============================

class ProfileCount extends StatelessWidget {
  final String title;
  final String count;

  const ProfileCount({
    super.key,
    required this.title,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          count,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(title),
      ],
    );
  }
}


// ==============================
// USER POSTS GRID
// ==============================

class UserPostsGrid extends StatelessWidget {
  final String uid;

  const UserPostsGrid({
    super.key,
    required this.uid,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: db
          .collection('posts')
          .where('uid', isEqualTo: uid)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState ==
            ConnectionState.waiting) {
          return const SizedBox(
            height: 200,
            child: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        final posts = snapshot.data?.docs ?? [];

        if (posts.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(30),
            child: Text('No posts yet'),
          );
        }

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: posts.length,
          gridDelegate:
              const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 2,
            mainAxisSpacing: 2,
          ),
          itemBuilder: (context, index) {
            final data = posts[index].data();
            final url = data['mediaUrl']?.toString() ?? '';

            return url.isEmpty
                ? const SizedBox()
                : Image.network(
                    url,
                    fit: BoxFit.cover,
                    errorBuilder:
                        (_, __, ___) => const Icon(
                      Icons.broken_image,
                    ),
                  );
          },
        );
      },
    );
  }
}


// ==============================
// EDIT PROFILE
// ==============================

class EditProfilePage extends StatefulWidget {
  final Map<String, dynamic> data;

  const EditProfilePage({
    super.key,
    required this.data,
  });

  @override
  State<EditProfilePage> createState() =>
      _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  late TextEditingController nameController;
  late TextEditingController usernameController;
  late TextEditingController pronounsController;
  late TextEditingController bioController;
  late TextEditingController linkController;
  late TextEditingController genderController;

  File? selectedPhoto;
  bool saving = false;
  bool privateProfile = false;

  @override
  void initState() {
    super.initState();

    nameController = TextEditingController(
      text: widget.data['name']?.toString() ?? '',
    );

    usernameController = TextEditingController(
      text: widget.data['username']?.toString() ?? '',
    );

    pronounsController = TextEditingController(
      text: widget.data['pronouns']?.toString() ?? '',
    );

    bioController = TextEditingController(
      text: widget.data['bio']?.toString() ?? '',
    );

    linkController = TextEditingController(
      text: widget.data['link']?.toString() ?? '',
    );

    genderController = TextEditingController(
      text: widget.data['gender']?.toString() ?? '',
    );

    privateProfile =
        widget.data['private'] == true;
  }

  @override
  void dispose() {
    nameController.dispose();
    usernameController.dispose();
    pronounsController.dispose();
    bioController.dispose();
    linkController.dispose();
    genderController.dispose();
    super.dispose();
  }

  Future<void> pickPhoto() async {
    final picker = ImagePicker();

    final file = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );

    if (file == null) return;

    setState(() {
      selectedPhoto = File(file.path);
    });
  }

  Future<void> saveProfile() async {
    if (currentUid == null) return;

    setState(() {
      saving = true;
    });

    try {
      String photoUrl =
          widget.data['photo']?.toString() ?? '';

      if (selectedPhoto != null) {
        photoUrl = await uploadFile(
          selectedPhoto!,
          'profile_photos/$currentUid.jpg',
        );
      }

      await db.collection('users').doc(currentUid).set(
        {
          'uid': currentUid,
          'name': nameController.text.trim(),
          'username':
              usernameController.text.trim().toLowerCase(),
          'pronouns': pronounsController.text.trim(),
          'bio': bioController.text.trim(),
          'link': linkController.text.trim(),
          'gender': genderController.text.trim(),
          'private': privateProfile,
          'photo': photoUrl,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated ✓'),
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final oldPhoto =
        widget.data['photo']?.toString() ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        actions: [
          TextButton(
            onPressed: saving ? null : saveProfile,
            child: saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  )
                : const Text('Save'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: GestureDetector(
              onTap: pickPhoto,
              child: CircleAvatar(
                radius: 55,
                backgroundImage: selectedPhoto != null
                    ? FileImage(selectedPhoto!)
                    : oldPhoto.isNotEmpty
                        ? NetworkImage(oldPhoto)
                        : null,
                child: selectedPhoto == null &&
                        oldPhoto.isEmpty
                    ? const Icon(
                        Icons.person,
                        size: 55,
                      )
                    : null,
              ),
            ),
          ),

          const SizedBox(height: 8),

          const Center(
            child: Text('Tap photo to change'),
          ),

          const SizedBox(height: 20),

          TextField(
            controller: nameController,
            decoration:
                const InputDecoration(labelText: 'Name'),
          ),

          TextField(
            controller: usernameController,
            decoration:
                const InputDecoration(labelText: 'Username'),
          ),

          TextField(
            controller: pronounsController,
            decoration:
                const InputDecoration(labelText: 'Pronouns'),
          ),

          TextField(
            controller: bioController,
            maxLines: 3,
            decoration:
                const InputDecoration(labelText: 'Bio'),
          ),

          TextField(
            controller: linkController,
            decoration:
                const InputDecoration(labelText: 'Link'),
          ),

          TextField(
            controller: genderController,
            decoration:
                const InputDecoration(labelText: 'Gender'),
          ),

          const SizedBox(height: 10),

          SwitchListTile(
            title: const Text('Private Profile'),
            subtitle: const Text(
              'Only approved followers can see your posts',
            ),
            value: privateProfile,
            onChanged: (value) {
              setState(() {
                privateProfile = value;
              });
            },
          ),
        ],
      ),
    );
  }
}


// ==============================
// OTHER USER PROFILE
// ==============================

class UserProfilePage extends StatefulWidget {
  final String uid;

  const UserProfilePage({
    super.key,
    required this.uid,
  });

  @override
  State<UserProfilePage> createState() =>
      _UserProfilePageState();
}

class _UserProfilePageState
    extends State<UserProfilePage> {
  bool following = false;
  bool loadingFollow = true;

  @override
  void initState() {
    super.initState();
    checkFollowing();
  }

  Future<void> checkFollowing() async {
    if (currentUid == null) return;

    final doc = await db
        .collection('users')
        .doc(currentUid)
        .collection('following')
        .doc(widget.uid)
        .get();

    if (mounted) {
      setState(() {
        following = doc.exists;
        loadingFollow = false;
      });
    }
  }

  Future<void> toggleFollow() async {
    if (currentUid == null ||
        currentUid == widget.uid) {
      return;
    }

    setState(() {
      loadingFollow = true;
    });
    
    final myFollowing = db
        .collection('users')
        .doc(currentUid)
        .collection('following')
        .doc(widget.uid);

    final theirFollowers = db
        .collection('users')
        .doc(widget.uid)
        .collection('followers')
        .doc(currentUid);

    final batch = db.batch();

    if (following) {
      batch.delete(myFollowing);
      batch.delete(theirFollowers);

      batch.set(
        db.collection('users').doc(currentUid),
        {
          'followingCount':
              FieldValue.increment(-1),
        },
        SetOptions(merge: true),
      );

      batch.set(
        db.collection('users').doc(widget.uid),
        {
          'followersCount':
              FieldValue.increment(-1),
        },
        SetOptions(merge: true),
      );
    } else {
      batch.set(myFollowing, {
        'uid': widget.uid,
        'createdAt': FieldValue.serverTimestamp(),
      });

      batch.set(theirFollowers, {
        'uid': currentUid,
        'createdAt': FieldValue.serverTimestamp(),
      });

      batch.set(
        db.collection('users').doc(currentUid),
        {
          'followingCount':
              FieldValue.increment(1),
        },
        SetOptions(merge: true),
      );

      batch.set(
        db.collection('users').doc(widget.uid),
        {
          'followersCount':
              FieldValue.increment(1),
        },
        SetOptions(merge: true),
      );
    }

    await batch.commit();

    if (mounted) {
      setState(() {
        following = !following;
        loadingFollow = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
      ),
      body: StreamBuilder<
          DocumentSnapshot<Map<String, dynamic>>>(
        stream: db
            .collection('users')
            .doc(widget.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final data = snapshot.data!.data() ?? {};

          final username =
              data['username']?.toString() ?? 'User';
          final name =
              data['name']?.toString() ?? '';
          final photo =
              data['photo']?.toString() ?? '';
          final bio =
              data['bio']?.toString() ?? '';

          return SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 20),

                CircleAvatar(
                  radius: 55,
                  backgroundImage: photo.isNotEmpty
                      ? NetworkImage(photo)
                      : null,
                  child: photo.isEmpty
                      ? const Icon(
                          Icons.person,
                          size: 50,
                        )
                      : null,
                ),

                const SizedBox(height: 10),

                Text(
                  username,
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                if (name.isNotEmpty)
                  Text(name),

                if (bio.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.all(15),
                    child: Text(
                      bio,
                      textAlign: TextAlign.center,
                    ),
                  ),

                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: loadingFollow
                          ? null
                          : toggleFollow,
                      child: Text(
                        following
                            ? 'Following'
                            : 'Follow',
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                UserPostsGrid(uid: widget.uid),
              ],
            ),
          );
        },
      ),
    );
  }
}


// ==============================
// PROFILE MENU
// ==============================

void showProfileMenu(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (context) {
      return SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'Settings & Privacy',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            ListTile(
              leading: const Icon(Icons.lock),
              title: const Text('App Lock'),
              subtitle: const Text(
                'Set PIN to protect the app',
              ),
              onTap: () {
                Navigator.pop(context);
                showSetPinDialog(context);
              },
            ),

            ListTile(
              leading: const Icon(Icons.security),
              title: const Text('Security'),
              onTap: () {},
            ),

            ListTile(
              leading: const Icon(Icons.notifications),
              title: const Text('Notifications'),
              onTap: () {},
            ),

            ListTile(
              leading: const Icon(Icons.visibility),
              title: const Text('Privacy'),
              onTap: () {},
            ),

            ListTile(
              leading: const Icon(Icons.block),
              title: const Text('Blocked Accounts'),
              onTap: () {},
            ),

            ListTile(
              leading: const Icon(Icons.person_off),
              title: const Text('Hidden Accounts'),
              onTap: () {},
            ),

            ListTile(
              leading: const Icon(Icons.language),
              title: const Text('Language'),
              onTap: () {},
            ),

            ListTile(
              leading: const Icon(Icons.help_outline),
              title: const Text('Help'),
              onTap: () {},
            ),

            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('About Instakilo'),
              onTap: () {},
            ),

            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: () async {
                Navigator.pop(context);
                await auth.signOut();
              },
            ),

            const SizedBox(height: 20),
          ],
        ),
      );
    },
  );
}


// ==============================
// SET APP PIN
// ==============================

Future<void> showSetPinDialog(
    BuildContext context) async {
  final controller = TextEditingController();

  await showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('Set App PIN'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          obscureText: true,
          maxLength: 6,
          decoration: const InputDecoration(
            hintText: 'Enter 4-6 digit PIN',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final pin = controller.text.trim();

              if (pin.length < 4) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(
                  const SnackBar(
                    content: Text(
                      'PIN minimum 4 digits hona chahiye',
                    ),
                  ),
                );
                return;
              }

              final prefs =
                  await SharedPreferences.getInstance();

              await prefs.setString(
                'app_lock_pin',
                pin,
              );

              await prefs.setBool(
                'profile_lock',
                true,
              );

              if (context.mounted) {
                Navigator.pop(context);

                ScaffoldMessenger.of(context)
                    .showSnackBar(
                  const SnackBar(
                    content: Text(
                      'App Lock ON ✓',
                    ),
                  ),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      );
    },
  );

  controller.dispose();
}


// ==============================
// LOCK SCREEN
// ==============================

class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  @override
  State<LockScreen> createState() =>
      _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final pinController = TextEditingController();

  bool checking = false;
  String error = '';

  Future<void> unlock() async {
    setState(() {
      checking = true;
      error = '';
    });

    final prefs =
        await SharedPreferences.getInstance();

    final savedPin =
        prefs.getString('app_lock_pin');

    if (savedPin == null) {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const MainNavigation(),
          ),
        );
      }
      return;
    }

    if (pinController.text == savedPin) {
      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const MainNavigation(),
        ),
      );
    } else {
      setState(() {
        error = 'Wrong PIN';
        checking = false;
      });
    }
  }

  @override
  void dispose() {
    pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisAlignment:
                MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.lock,
                size: 70,
              ),

              const SizedBox(height: 20),

              const Text(
                'INSTAKILO',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 10),

              const Text(
                'Enter your PIN',
              ),

              const SizedBox(height: 20),

              TextField(
                controller: pinController,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 6,
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  errorText:
                      error.isEmpty ? null : error,
                  border: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(15),
                  ),
                ),
              ),

              const SizedBox(height: 15),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: checking ? null : unlock,
                  child: checking
                      ? const CircularProgressIndicator()
                      : const Text('Unlock'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
// ========================= PART 5 =========================
// SETTINGS + EDIT PROFILE + LOGOUT + EXTRA SCREENS
// ==========================================================

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text('Edit Profile'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const EditProfilePage(),
                ),
              );
            },
          ),

          ListTile(
            leading: const Icon(Icons.lock_outline),
            title: const Text('Privacy'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),

          ListTile(
            leading: const Icon(Icons.notifications_none),
            title: const Text('Notifications'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),

          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('About Instakilo'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: 'Instakilo',
                applicationVersion: '1.0.0',
                applicationLegalese: '© 2026 Instakilo',
              );
            },
          ),

          const Divider(),

          ListTile(
            leading: const Icon(
              Icons.logout,
              color: Colors.red,
            ),
            title: const Text(
              'Logout',
              style: TextStyle(color: Colors.red),
            ),
            onTap: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) {
                  return AlertDialog(
                    title: const Text('Logout'),
                    content: const Text(
                      'Are you sure you want to logout?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context, false);
                        },
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context, true);
                        },
                        child: const Text('Logout'),
                      ),
                    ],
                  );
                },
              );

              if (confirm == true) {
                try {
                  await FirebaseAuth.instance.signOut();
                } catch (_) {}

                if (context.mounted) {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const LoginPage(),
                    ),
                    (route) => false,
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }
}


// ========================= EDIT PROFILE =========================

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final TextEditingController nameController =
      TextEditingController();

  final TextEditingController bioController =
      TextEditingController();

  bool saving = false;

  @override
  void initState() {
    super.initState();
    loadProfile();
  }

  Future<void> loadProfile() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (doc.exists) {
        final data = doc.data() ?? {};

        nameController.text =
            data['name']?.toString() ??
            data['username']?.toString() ??
            '';

        bioController.text =
            data['bio']?.toString() ?? '';
      } else {
        nameController.text =
            user.displayName ?? '';
      }

      if (mounted) {
        setState(() {});
      }
    } catch (_) {}
  }

  Future<void> saveProfile() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    setState(() {
      saving = true;
    });

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set(
        {
          'name': nameController.text.trim(),
          'bio': bioController.text.trim(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      await user.updateDisplayName(
        nameController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated'),
          ),
        );

        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
          ),
        );
      }
    }

    if (mounted) {
      setState(() {
        saving = false;
      });
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    bioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Edit Profile',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          TextButton(
            onPressed: saving ? null : saveProfile,
            child: saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  )
                : const Text('Save'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            CircleAvatar(
              radius: 48,
              child: Text(
                nameController.text.isNotEmpty
                    ? nameController.text[0].toUpperCase()
                    : 'I',
                style: const TextStyle(
                  fontSize: 35,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            const SizedBox(height: 30),

            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                prefixIcon: Icon(Icons.person_outline),
                border: OutlineInputBorder(),
              ),
              onChanged: (_) {
                setState(() {});
              },
            ),

            const SizedBox(height: 18),

            TextField(
              controller: bioController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Bio',
                alignLabelWithHint: true,
                prefixIcon: Icon(Icons.edit_outlined),
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 25),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: saving ? null : saveProfile,
                child: saving
                    ? const CircularProgressIndicator()
                    : const Text(
                        'Save Changes',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


// ========================= LOGIN PAGE =========================

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool loading = false;
  bool hidePassword = true;

  Future<void> login() async {
    if (emailController.text.trim().isEmpty ||
        passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Email and password required'),
        ),
      );
      return;
    }

    setState(() {
      loading = true;
    });

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text,
      );

      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => const HomePage(),
          ),
          (route) => false,
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.message ?? 'Login failed',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
          ),
        );
      }
    }

    if (mounted) {
      setState(() {
        loading = false;
      });
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const Text(
                  'Instakilo',
                  style: TextStyle(
                    fontSize: 42,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 10),

                const Text(
                  'Share your world',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                ),

                const SizedBox(height: 45),

                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email_outlined),
                    border: OutlineInputBorder(),
                  ),
                ),

                const SizedBox(height: 18),

                TextField(
                  controller: passwordController,
                  obscureText: hidePassword,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        hidePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(() {
                          hidePassword = !hidePassword;
                        });
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 25),

                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: loading ? null : login,
                    child: loading
                        ? const CircularProgressIndicator()
                        : const Text(
                            'Login',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 18),

                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const SignupPage(),
                      ),
                    );
                  },
                  child: const Text(
                    "Don't have an account? Sign up",
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


// ========================= SIGNUP PAGE =========================

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool loading = false;
  bool hidePassword = true;

  Future<void> signup() async {
    if (nameController.text.trim().isEmpty ||
        emailController.text.trim().isEmpty ||
        passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all fields'),
        ),
      );
      return;
    }

    if (passwordController.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Password must be at least 6 characters',
          ),
        ),
      );
      return;
    }

    setState(() {
      loading = true;
    });

    try {
      final credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text,
      );

      final user = credential.user;

      if (user != null) {
        await user.updateDisplayName(
          nameController.text.trim(),
        );

        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .set({
          'uid': user.uid,
          'name': nameController.text.trim(),
          'email': emailController.text.trim(),
          'bio': '',
          'followers': [],
          'following': [],
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => const HomePage(),
          ),
          (route) => false,
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.message ?? 'Signup failed',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
          ),
        );
      }
    }

    if (mounted) {
      setState(() {
        loading = false;
      });
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Account'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 20),

              const Text(
                'Create your Instakilo account',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 35),

              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  prefixIcon: Icon(Icons.person_outline),
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 18),

              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email_outlined),
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 18),

              TextField(
                controller: passwordController,
                obscureText: hidePassword,
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(
                      hidePassword
                          ? Icons.visibility_off
                          : Icons.visibility,
                    ),
                    onPressed: () {
                      setState(() {
                        hidePassword = !hidePassword;
                      });
                    },
                  ),
                ),
              ),

              const SizedBox(height: 25),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: loading ? null : signup,
                  child: loading
                      ? const CircularProgressIndicator()
                      : const Text(
                          'Create Account',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 15),

              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text(
                  'Already have an account? Login',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
