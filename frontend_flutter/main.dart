import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: EmailScreen(),
    );
  }
}

class EmailScreen extends StatefulWidget {
  const EmailScreen({super.key});

  @override
  _EmailScreenState createState() => _EmailScreenState();
}

class _EmailScreenState extends State<EmailScreen> {
  List emails = [];
  bool isLoading = true;

  String? nextPageToken;
  bool isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    fetchEmails();
    startAutoRefresh();
  }

  void startAutoRefresh() {
    Future.doWhile(() async {
      await Future.delayed(Duration(seconds: 10));
      if (!mounted) return false;
      await fetchEmails();
      return true;
    });
  }

  Future<void> fetchEmails() async {
    try {
      final url = nextPageToken == null
    ? "http://localhost:8000/emails"
    : "http://localhost:8000/emails?page_token=$nextPageToken";
    final res = await http.get(Uri.parse(url));
    final data = json.decode(res.body);
      setState(() {
        if (nextPageToken == null) {
          emails = data['emails'];
        } else {
          emails.addAll(data['emails']);
        }
        nextPageToken = data['nextPageToken'];
        isLoading = false;
      });
    } catch (e) {
      print("Error fetching emails: $e");
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> showInboxSummary() async {
    try {
      final res = await http.get(Uri.parse("http://localhost:8000/summary"));
      final data = json.decode(res.body);

      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text("Inbox Summary"),
          content: Text(data['summary'] ?? "No summary"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Close"),
            )
          ],
        ),
      );
    } catch (e) {
      print("Summary error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.grey[100],
        appBar: AppBar(
          title: Text(
            "📬 AI Student Inbox",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.deepPurple,
          foregroundColor: Colors.white,
          elevation: 2,
          bottom: TabBar(
            tabs: [
              Tab(text: "Important"),
              Tab(text: "All"),
            ],
          ),
          actions: [
            IconButton(
              icon: Icon(Icons.analytics),
              onPressed: showInboxSummary,
            ),
          ],
        ),
        body: isLoading
            ? Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: () async {
                  nextPageToken = null;
                  await fetchEmails();
                },
                child: NotificationListener<ScrollNotification>(
                  onNotification: (scrollInfo) {
                    if (!isLoadingMore &&
                        scrollInfo.metrics.pixels >=
                            scrollInfo.metrics.maxScrollExtent - 100 &&
                        nextPageToken != null) {
                      isLoadingMore = true;
                      fetchEmails().then((_) {
                        isLoadingMore = false;
                      });
                    }
                    return false;
                  },
                  child: TabBarView(
                    children: [
                      buildEmailList(true),
                      buildEmailList(false),
                    ],
                  ),
                ),
              ),
        floatingActionButton: FloatingActionButton(
          backgroundColor: Colors.deepPurple,
          onPressed: fetchEmails,
          child: Icon(Icons.refresh),
        ),
      ),
    );
  }

  Widget buildEmailList(bool importantOnly) {
    List filtered = emails;

    if (importantOnly) {
      filtered = emails
          .where((e) =>
              (e['summary'] ?? "").toLowerCase().contains("important"))
          .toList();
    }

    if (filtered.isEmpty) {
      return Center(child: Text("No emails"));
    }

    return ListView.builder(
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final email = filtered[index];
        String summary = email['summary'] ?? "";

        String priority = "Normal";
        if (summary.toLowerCase().contains("important")) {
          priority = "Important";
        } else if (summary.toLowerCase().contains("ignore")) {
          priority = "Ignore";
        }

        Color color = priority == "Important"
            ? Colors.red
            : priority == "Ignore"
                ? Colors.grey
                : Colors.blue;

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => EmailDetailScreen(email: email),
              ),
            );
          },
          child: AnimatedContainer(
            duration: Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            margin: EdgeInsets.all(10),
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (email['unread'] == true)
                  Container(
                    width: 8,
                    height: 8,
                    margin: EdgeInsets.only(bottom: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      shape: BoxShape.circle,
                    ),
                  ),
                Text(email['subject'] ?? "No Subject",
                    style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(height: 5),
                Text(summary),
                SizedBox(height: 5),
                Row(
                  children: [
                    Text(priority,
                        style: TextStyle(
                            color: color, fontWeight: FontWeight.bold)),
                    Spacer(),
                    Text(email['sender'] ?? "",
                        style: TextStyle(fontSize: 10))
                  ],
                )
              ],
            ),
          ),
        );
      },
    );
  }
}

class EmailDetailScreen extends StatefulWidget {
  final email;

  const EmailDetailScreen({super.key, required this.email});

  @override
  _EmailDetailScreenState createState() => _EmailDetailScreenState();
}

class _EmailDetailScreenState extends State<EmailDetailScreen> {
  String reply = "";
  bool loading = false;

  Future<void> generateReply() async {
    setState(() {
      loading = true;
    });

    try {
      final res = await http.post(
        Uri.parse("http://localhost:8000/reply"),
        headers: {"Content-Type": "application/json"},
        body: json.encode({"text": widget.email['summary'] ?? ""}),
      );

      final data = json.decode(res.body);

      setState(() {
        reply = data['reply'] ?? "";
        loading = false;
      });
    } catch (e) {
      print("Reply error: $e");
      setState(() {
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.email['subject'] ?? "Email"),
        backgroundColor: Colors.deepPurple,
      ),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.email['summary'] ?? "",
                style: TextStyle(fontSize: 16)),

            SizedBox(height: 20),

            ElevatedButton(
              onPressed: generateReply,
              child: Text("Generate AI Reply"),
            ),

            SizedBox(height: 20),

            if (loading) CircularProgressIndicator(),

            if (reply.isNotEmpty)
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(reply),
              ),
          ],
        ),
      ),
    );
  }
}
