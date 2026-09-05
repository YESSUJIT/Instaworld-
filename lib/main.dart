import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp();

  runApp(const InstaWorldApp());
}

class InstaWorldApp extends StatelessWidget {
  const InstaWorldApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'InstaWorld',
      theme: ThemeData(
        brightness: Brightness.light,
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.white,
      ),
      home: const AuthGate(),
    );
  }
}

// ------------------------------------------------------------
// AUTH GATE
// ------------------------------------------------------------

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasData) {
          return const HomePage();
        }

        return const LoginPage();
      },
    );
  }
}

// ------------------------------------------------------------
// LOGIN
// ------------------------------------------------------------

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool loading = false;
  bool obscurePassword = true;

  Future<void> login() async {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      showMessage('Email aur password enter karo');
      return;
    }

    setState(() => loading = true);

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      showMessage(authError(e));
    } catch (e) {
      showMessage('Login failed');
    }

    if (mounted) {
      setState(() => loading = false);
    }
  }

  Future<void> guestLogin() async {
    setState(() => loading = true);

    try {
      final credential =
          await FirebaseAuth.instance.signInAnonymously();

      final user = credential.user;

      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .set(
          {
            'uid': user.uid,
            'username': 'guest_${user.uid.substring(0, 6)}',
            'displayName': 'Guest',
            'email': '',
            'photoUrl': '',
            'bio': '',
            'isGuest': true,
            'createdAt': FieldValue.serverTimestamp(),
            'followersCount': 0,
            'followingCount': 0,
            'postsCount': 0,
          },
          SetOptions(merge: true),
        );
      }
    } on FirebaseAuthException catch (e) {
      showMessage(authError(e));
    } catch (e) {
      showMessage('Guest login failed');
    }

    if (mounted) {
      setState(() => loading = false);
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
                const SizedBox(height: 30),

                const Text(
                  'InstaWorld',
                  style: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 40),

                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                ),

                const SizedBox(height: 16),

                TextField(
                  controller: passwordController,
                  obscureText: obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      onPressed: () {
                        setState(() {
                          obscurePassword = !obscurePassword;
                        });
                      },
                      icon: Icon(
                        obscurePassword
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: loading ? null : login,
                    child: loading
                        ? const CircularProgressIndicator()
                        : const Text(
                            'Login',
                            style: TextStyle(fontSize: 17),
                          ),
                  ),
                ),

                const SizedBox(height: 12),

                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const SignupPage(),
                      ),
                    );
                  },
                  child: const Text('Create new account'),
                ),

                const Divider(height: 30),

                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: loading ? null : guestLogin,
                    icon: const Icon(Icons.person_outline),
                    label: const Text('Continue as Guest'),
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

// ------------------------------------------------------------
// SIGNUP
// ------------------------------------------------------------

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final usernameController = TextEditingController();
  final nameController = TextEditingController();

  bool loading = false;

  Future<void> signup() async {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();
    final username = usernameController.text.trim().toLowerCase();
    final name = nameController.text.trim();

    if (email.isEmpty ||
        password.isEmpty ||
        username.isEmpty ||
        name.isEmpty) {
      showMessage('Sabhi fields fill karo');
      return;
    }

    if (password.length < 6) {
      showMessage('Password kam se kam 6 characters ka hona chahiye');
      return;
    }

    setState(() => loading = true);

    try {
      final existing = await FirebaseFirestore.instance
          .collection('users')
          .where('username', isEqualTo: username)
          .limit(1)
          .get();

      if (existing.docs.isNotEmpty) {
        showMessage('Username already taken');
        setState(() => loading = false);
        return;
      }

      final credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = credential.user;

      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .set({
          'uid': user.uid,
          'username': username,
          'displayName': name,
          'email': email,
          'photoUrl': '',
          'bio': '',
          'isGuest': false,
          'createdAt': FieldValue.serverTimestamp(),
          'followersCount': 0,
          'followingCount': 0,
          'postsCount': 0,
        });
      }
    } on FirebaseAuthException catch (e) {
      showMessage(authError(e));
    } catch (e) {
      showMessage('Signup failed');
    }

    if (mounted) {
      setState(() => loading = false);
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    usernameController.dispose();
    nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create account'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 16),

              TextField(
                controller: usernameController,
                decoration: const InputDecoration(
                  labelText: 'Username',
                  prefixText: '@',
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 16),

              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 16),

              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: loading ? null : signup,
                  child: loading
                      ? const CircularProgressIndicator()
                      : const Text('Sign up'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------
// HOME
// ------------------------------------------------------------

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int currentIndex = 0;

  final pages = const [
    HomeFeedPage(),
    SearchPage(),
    ReelsPage(),
    NotificationsPage(),
    ProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: pages[currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (index) {
          setState(() => currentIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.search_outlined),
            selectedIcon: Icon(Icons.search),
            label: 'Search',
          ),
          NavigationDestination(
            icon: Icon(Icons.movie_outlined),
            selectedIcon: Icon(Icons.movie),
            label: 'Reels',
          ),
          NavigationDestination(
            icon: Icon(Icons.favorite_border),
            selectedIcon: Icon(Icons.favorite),
            label: 'Activity',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------
// HOME FEED
// ------------------------------------------------------------

class HomeFeedPage extends StatelessWidget {
  const HomeFeedPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'InstaWorld',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const UploadPage(),
                ),
              );
            },
            icon: const Icon(Icons.add_box_outlined),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('posts')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return const Center(
              child: Text('Feed load nahi ho saka'),
            );
          }

          final posts = snapshot.data?.docs ?? [];

          if (posts.isEmpty) {
            return const Center(
              child: Text(
                'Abhi koi post nahi hai.\n+ button se first post upload karo.',
                textAlign: TextAlign.center,
              ),
            );
          }

          return ListView.builder(
            itemCount: posts.length,
            itemBuilder: (context, index) {
              final data = posts[index].data();

              return PostCard(
                postId: posts[index].id,
                data: data,
              );
            },
          );
        },
      ),
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
  bool liking = false;

  DocumentReference<Map<String, dynamic>> get postRef =>
      FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.postId);

  Future<void> toggleLike() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null || liking) return;

    setState(() => liking = true);

    try {
      final likeRef = postRef.collection('likes').doc(uid);
      final likeDoc = await likeRef.get();

      if (likeDoc.exists) {
        await likeRef.delete();
        await postRef.update({
          'likesCount': FieldValue.increment(-1),
        });
      } else {
        await likeRef.set({
          'uid': uid,
          'createdAt': FieldValue.serverTimestamp(),
        });

        await postRef.update({
          'likesCount': FieldValue.increment(1),
        });
      }
    } catch (_) {}

    if (mounted) {
      setState(() => liking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final username =
        widget.data['username']?.toString() ?? 'user';

    final caption =
        widget.data['caption']?.toString() ?? '';

    final imageUrl =
        widget.data['imageUrl']?.toString() ?? '';

    final likes =
        (widget.data['likesCount'] ?? 0) as num;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          leading: const CircleAvatar(
            child: Icon(Icons.person),
          ),
          title: Text(
            username,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),

        if (imageUrl.isNotEmpty)
          AspectRatio(
            aspectRatio: 1,
            child: Image.network(
              imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) {
                return const Center(
                  child: Icon(Icons.broken_image),
                );
              },
            ),
          ),

        Row(
          children: [
            IconButton(
              onPressed: toggleLike,
              icon: const Icon(Icons.favorite_border),
            ),
            IconButton(
              onPressed: () {
                showMessage('Comment system next step mein add hoga');
              },
              icon: const Icon(Icons.comment_outlined),
            ),
            IconButton(
              onPressed: () {
                showMessage('Save system next step mein add hoga');
              },
              icon: const Icon(Icons.bookmark_border),
            ),
            const Spacer(),
            IconButton(
              onPressed: () {
                showMessage('Share system next step mein add hoga');
              },
              icon: const Icon(Icons.share_outlined),
            ),
          ],
        ),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            '$likes likes',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),

        if (caption.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              16,
              6,
              16,
              16,
            ),
            child: Text(
              '$username $caption',
            ),
          ),
      ],
    );
  }
}

// ------------------------------------------------------------
// SEARCH
// ------------------------------------------------------------

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final searchController = TextEditingController();

  bool searching = false;
  List<QueryDocumentSnapshot<Map<String, dynamic>>> results = [];

  Future<void> searchUsers() async {
    final text = searchController.text.trim().toLowerCase();

    if (text.isEmpty) {
      setState(() => results = []);
      return;
    }

    setState(() => searching = true);

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where(
            'username',
            isGreaterThanOrEqualTo: text,
          )
          .where(
            'username',
            isLessThanOrEqualTo: '$text\uf8ff',
          )
          .limit(20)
          .get();

      setState(() {
        results = snapshot.docs;
      });
    } catch (_) {
      showMessage('Search failed');
    }

    setState(() => searching = false);
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: searchController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Search username...',
            border: InputBorder.none,
          ),
          onSubmitted: (_) => searchUsers(),
        ),
        actions: [
          IconButton(
            onPressed: searchUsers,
            icon: const Icon(Icons.search),
          ),
        ],
      ),
      body: searching
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : ListView.builder(
              itemCount: results.length,
              itemBuilder: (context, index) {
                final data = results[index].data();

                return ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.person),
                  ),
                  title: Text(
                    '@${data['username'] ?? ''}',
                  ),
                  subtitle: Text(
                    data['displayName'] ?? '',
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => UserProfilePage(
                          userId: results[index].id,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}

// ------------------------------------------------------------
// REELS
// ------------------------------------------------------------

class ReelsPage extends StatelessWidget {
  const ReelsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reels'),
      ),
      body: const Center(
        child: Text(
          'Reels system next step mein add hoga',
        ),
      ),
    );
  }
}

// ------------------------------------------------------------
// NOTIFICATIONS
// ------------------------------------------------------------

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      return const Scaffold(
        body: Center(
          child: Text('Login required'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('notifications')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final notifications = snapshot.data!.docs;

          if (notifications.isEmpty) {
            return const Center(
              child: Text('No notifications'),
            );
          }

          return ListView.builder(
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final data = notifications[index].data();

              return ListTile(
                leading: const CircleAvatar(
                  child: Icon(Icons.notifications),
                ),
                title: Text(
                  data['message']?.toString() ??
                      'New activity',
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ------------------------------------------------------------
// PROFILE
// ------------------------------------------------------------

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      return const Scaffold(
        body: Center(
          child: Text('Login required'),
        ),
      );
    }

    return UserProfilePage(
      userId: uid,
      ownProfile: true,
    );
  }
}

// ------------------------------------------------------------
// USER PROFILE
// ------------------------------------------------------------

class UserProfilePage extends StatelessWidget {
  final String userId;
  final bool ownProfile;

  const UserProfilePage({
    super.key,
    required this.userId,
    this.ownProfile = false,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: FutureBuilder<
            DocumentSnapshot<Map<String, dynamic>>>(
          future: FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .get(),
          builder: (context, snapshot) {
            final username =
                snapshot.data?.data()?['username'];

            return Text(
              username != null
                  ? '@$username'
                  : 'Profile',
            );
          },
        ),
        actions: [
          if (ownProfile)
            IconButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const SettingsPage(),
                  ),
                );
              },
              icon: const Icon(Icons.menu),
            ),
        ],
      ),
      body: StreamBuilder<
          DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final data = snapshot.data!.data() ?? {};

          final name =
              data['displayName']?.toString() ?? '';

          final username =
              data['username']?.toString() ?? '';

          final bio =
              data['bio']?.toString() ?? '';

          final photoUrl =
              data['photoUrl']?.toString() ?? '';

          final followers =
              data['followersCount'] ?? 0;

          final following =
              data['followingCount'] ?? 0;

          final posts =
              data['postsCount'] ?? 0;

          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 42,
                        backgroundImage:
                            photoUrl.isNotEmpty
                                ? NetworkImage(photoUrl)
                                : null,
                        child: photoUrl.isEmpty
                            ? const Icon(
                                Icons.person,
                                size: 42,
                              )
                            : null,
                      ),

                      const SizedBox(width: 25),

                      Expanded(
                        child: Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceAround,
                          children: [
                            profileCount(
                              'Posts',
                              posts,
                            ),
                            profileCount(
                              'Followers',
                              followers,
                            ),
                            profileCount(
                              'Following',
                              following,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('@$username'),
                  ),

                  if (bio.isNotEmpty)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding:
                            const EdgeInsets.only(top: 6),
                        child: Text(bio),
                      ),
                    ),

                  const SizedBox(height: 15),

                  if (ownProfile)
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () {
                          showMessage(
                            'Edit Profile next step mein add hoga',
                          );
                        },
                        child: const Text('Edit profile'),
                      ),
                    )
                  else
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          showMessage(
                            'Follow system next step mein add hoga',
                          );
                        },
                        child: const Text('Follow'),
                      ),
                    ),

                  const Divider(height: 30),

                  const Text(
                    'Posts',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),

                  const SizedBox(height: 20),

                  const Center(
                    child: Text(
                      'No posts yet',
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget profileCount(
    String title,
    dynamic count,
  ) {
    return Column(
      children: [
        Text(
          '$count',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        Text(title),
      ],
    );
  }
}

// ------------------------------------------------------------
// UPLOAD
// ------------------------------------------------------------

class UploadPage extends StatefulWidget {
  const UploadPage({super.key});

  @override
  State<UploadPage> createState() => _UploadPageState();
}

class _UploadPageState extends State<UploadPage> {
  final ImagePicker _picker = ImagePicker();
  final TextEditingController captionController = TextEditingController();

  File? selectedFile;
  bool isVideo = false;
  bool uploading = false;

  // 📷 Camera Photo
  Future<void> cameraPhoto() async {
    final XFile? file = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 90,
    );

    if (file == null) return;

    setState(() {
      selectedFile = File(file.path);
      isVideo = false;
    });

    await saveToGallery(file.path, false);
  }

  // 🎥 Camera Video
  Future<void> cameraVideo() async {
    final XFile? file = await _picker.pickVideo(
      source: ImageSource.camera,
      maxDuration: const Duration(minutes: 5),
    );

    if (file == null) return;

    setState(() {
      selectedFile = File(file.path);
      isVideo = true;
    });

    await saveToGallery(file.path, true);
  }

  // 🖼️ Gallery Photo
  Future<void> galleryPhoto() async {
    final XFile? file = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
    );

    if (file == null) return;

    setState(() {
      selectedFile = File(file.path);
      isVideo = false;
    });
  }

  // 🎬 Gallery Video
  Future<void> galleryVideo() async {
    final XFile? file = await _picker.pickVideo(
      source: ImageSource.gallery,
    );

    if (file == null) return;

    setState(() {
      selectedFile = File(file.path);
      isVideo = true;
    });
  }

  // 💾 Save camera media to phone gallery
  Future<void> saveToGallery(String path, bool video) async {
    try {
      if (video) {
        await Gal.putVideo(path);
      } else {
        await Gal.putImage(path);
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Saved to Gallery'),
        ),
      );
    } catch (e) {
      // Gallery save fail hone par upload phir bhi continue ho sakta hai.
    }
  }

  // ⬆️ Firebase Upload
  Future<void> uploadPost() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      showMessage('Please login first');
      return;
    }

    if (selectedFile == null) {
      showMessage('Please select Photo or Video');
      return;
    }

    setState(() {
      uploading = true;
    });

    try {
      final String fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${user.uid}';

      final String folder = isVideo ? 'videos' : 'images';

      final Reference storageRef = FirebaseStorage.instance
          .ref()
          .child('posts')
          .child(folder)
          .child(fileName);

      await storageRef.putFile(selectedFile!);

      final String downloadUrl =
          await storageRef.getDownloadURL();

      await FirebaseFirestore.instance
          .collection('posts')
          .add({
        'userId': user.uid,
        'mediaUrl': downloadUrl,
        'mediaType': isVideo ? 'video' : 'image',
        'caption': captionController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'likes': [],
      });

      if (!mounted) return;

      setState(() {
        selectedFile = null;
        isVideo = false;
        captionController.clear();
        uploading = false;
      });

      showMessage('Post uploaded successfully');

    } catch (e) {
      if (!mounted) return;

      setState(() {
        uploading = false;
      });

      showMessage('Upload failed');
    }
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  void dispose() {
    captionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Post'),
        centerTitle: true,
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [

            // Preview
            Container(
              width: double.infinity,
              height: 300,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(18),
              ),
              clipBehavior: Clip.antiAlias,
              child: selectedFile == null
                  ? const Center(
                      child: Text(
                        'Select Photo or Video',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey,
                        ),
                      ),
                    )
                  : isVideo
                      ? const Center(
                          child: Icon(
                            Icons.play_circle_fill,
                            size: 80,
                            color: Colors.black54,
                          ),
                        )
                      : Image.file(
                          selectedFile!,
                          fit: BoxFit.cover,
                        ),
            ),

            const SizedBox(height: 20),

            // 📷 Camera Photo
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: uploading ? null : cameraPhoto,
                icon: const Icon(Icons.camera_alt),
                label: const Text('Camera Photo'),
              ),
            ),

            const SizedBox(height: 10),

            // 🎥 Camera Video
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: uploading ? null : cameraVideo,
                icon: const Icon(Icons.videocam),
                label: const Text('Camera Video'),
              ),
            ),

            const SizedBox(height: 10),

            // 🖼️ Gallery Photo
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: uploading ? null : galleryPhoto,
                icon: const Icon(Icons.photo),
                label: const Text('Gallery Photo'),
              ),
            ),

            const SizedBox(height: 10),

            // 🎬 Gallery Video
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: uploading ? null : galleryVideo,
                icon: const Icon(Icons.video_library),
                label: const Text('Gallery Video'),
              ),
            ),

            const SizedBox(height: 20),

            // Caption
            TextField(
              controller: captionController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Write a caption...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // ⬆️ Upload
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: uploading ? null : uploadPost,
                icon: uploading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.cloud_upload),
                label: Text(
                  uploading ? 'Uploading...' : 'Upload Post',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
// ------------------------------------------------------------
// SETTINGS
// ------------------------------------------------------------

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  Future<void> logout() async {
    await FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text('Edit Profile'),
            onTap: () {
              showMessage(
                'Edit Profile next step mein add hoga',
              );
            },
          ),

          ListTile(
            leading: const Icon(Icons.bookmark_outline),
            title: const Text('Saved'),
            onTap: () {
              showMessage(
                'Saved next step mein add hoga',
              );
            },
          ),

          ListTile(
            leading: const Icon(Icons.history),
            title: const Text('Your activity'),
            onTap: () {
              showMessage(
                'Your Activity next step mein add hoga',
              );
            },
          ),

          ListTile(
            leading: const Icon(Icons.lock_outline),
            title: const Text('Privacy'),
            onTap: () {},
          ),

          ListTile(
            leading: const Icon(Icons.security),
            title: const Text('Security'),
            onTap: () {},
          ),

          ListTile(
            leading: const Icon(Icons.notifications_outlined),
            title: const Text('Notifications'),
            onTap: () {},
          ),

          ListTile(
            leading: const Icon(Icons.help_outline),
            title: const Text('Help'),
            onTap: () {},
          ),

          const Divider(),

          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Log out'),
            onTap: logout,
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------
// HELPERS
// ------------------------------------------------------------

String authError(FirebaseAuthException e) {
  switch (e.code) {
    case 'invalid-email':
      return 'Email address invalid hai';

    case 'user-not-found':
      return 'Account nahi mila';

    case 'wrong-password':
      return 'Password galat hai';

    case 'email-already-in-use':
      return 'Email already registered hai';

    case 'weak-password':
      return 'Password weak hai';

    case 'invalid-credential':
      return 'Email ya password galat hai';

    case 'network-request-failed':
      return 'Internet connection check karo';

    case 'operation-not-allowed':
      return 'Firebase Console mein login method enable karo';

    default:
      return e.message ?? 'Authentication failed';
  }
}

void showMessage(String message) {
  debugPrint(message);
}
