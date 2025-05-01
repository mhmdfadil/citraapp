import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final List<ChatMessage> _messages = [
    ChatMessage(
      text: 'Hai selamat datang di Toko Citra Kosmetik. Apakah bisa saya bantu?',
      isMe: false,
    ),
  ];

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  void _sendMessage(String text) {
    if (text.trim().isEmpty) return;

    setState(() {
      _messages.add(ChatMessage(text: text, isMe: true));
      _messageController.clear();
    });

    // Scroll to bottom
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final scrollController = PrimaryScrollController.of(context);
        scrollController?.animateTo(
          scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF273F0),
      body: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const FaIcon(FontAwesomeIcons.arrowLeft, size: 18),
                    onPressed: () => Navigator.pop(context),
                    color: Colors.black,
                    padding: EdgeInsets.zero,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Chat',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
          ),

          // Chat header
          Container(
            padding: const EdgeInsets.all(8),
            color: Color.fromARGB(255, 243, 207, 242),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.network(
                    'assets/images/logo.png',
                    width: 40,
                    height: 40,
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    color: Colors.grey[300],
                    child: const Text(
                      'TOKO CITRA KOSMETIK',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.purple,
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Chat messages container
          Expanded(
            child: Container(
              color: Colors.grey[50],
              padding: const EdgeInsets.all(16),
              child: ListView.builder(
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final message = _messages[index];
                  return Align(
                    alignment:
                        message.isMe ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 280),
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: message.isMe ? Colors.pink[200] : Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!message.isMe)
                            const FaIcon(
                              FontAwesomeIcons.store,
                              size: 20,
                              color: Colors.purple,
                            ),
                          if (!message.isMe) const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              message.text,
                              style: TextStyle(
                                fontSize: 14,
                                color: message.isMe
                                    ? Colors.black.withOpacity(0.8)
                                    : Colors.black,
                              ),
                            ),
                          ),
                          if (message.isMe) const SizedBox(width: 8),
                          if (message.isMe)
                            const FaIcon(
                              FontAwesomeIcons.userCircle,
                              size: 20,
                              color: Colors.black,
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // Input and quick replies container
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.pink[200],
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: TextField(
                          controller: _messageController,
                          decoration: InputDecoration(
                            hintText: 'Tulis Pesan .......',
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.all(16),
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.send),
                              onPressed: () =>
                                  _sendMessage(_messageController.text),
                            ),
                          ),
                          style: const TextStyle(fontSize: 18),
                          onSubmitted: (text) => _sendMessage(text),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildQuickReply('Apakah produk ini ready stock?'),
                      const SizedBox(height: 8),
                      _buildQuickReply('Apa saja metode pembayaran yang tersedia?'),
                      const SizedBox(height: 8),
                      _buildQuickReply('Bagaimana cara melakukan pemesanan?'),
                    ],
                  ),
                )
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickReply(String text) {
    return GestureDetector(
      onTap: () => _sendMessage(text),
      child: Container(
        width: 280,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 14,
            color: Colors.black,
          ),
          softWrap: true,
        ),
      ),
    );
  }
}

class ChatMessage {
  final String text;
  final bool isMe;

  ChatMessage({required this.text, required this.isMe});
}