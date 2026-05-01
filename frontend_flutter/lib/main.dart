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
      print("Error: $e");
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text("📬 AI Student Inbox"),
        backgroundColor: Colors.deepPurple,
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : NotificationListener<ScrollNotification>(
              onNotification: (scrollInfo) {
                if (!isLoadingMore &&
                    scrollInfo.metrics.pixels >= scrollInfo.metrics.maxScrollExtent - 100 &&
                    nextPageToken != null) {
                  isLoadingMore = true;
                  fetchEmails().then((_) {
                    isLoadingMore = false;
                  });
                }
                return false;
              },
              child: ListView.builder(
                itemCount: emails.length + (nextPageToken != null ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index >= emails.length) {
                    return Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  final email = emails[index];

                  String summary = email['summary'] ?? "";
                  String priority = email['priority'] ?? "Normal";

                  Color color = priority == "Important"
                      ? Colors.red
                      : priority == "Ignore"
                          ? Colors.grey
                          : Colors.blue;

                  return Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: 700),
                      child: Container(
                        margin: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                        padding: EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: priority == "Important"
                              ? Colors.red.withOpacity(0.08)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: priority == "Important"
                                ? Colors.red
                                : Colors.grey.shade200,
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 6,
                              offset: Offset(0, 2),
                            )
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // SUBJECT
                            Text(
                              email['subject'] ?? "No Subject",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),

                            SizedBox(height: 6),

                            // SUMMARY
                            Text(
                              summary,
                              style: TextStyle(
                                color: Colors.grey[700],
                                fontSize: 13,
                              ),
                            ),

                            SizedBox(height: 10),

                            // FOOTER ROW
                            Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: color.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    priority,
                                    style: TextStyle(
                                      color: color,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),

                                Spacer(),

                                Flexible(
                                  child: Text(
                                    email['sender'] ?? "",
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ),
                              ],
                            )
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}