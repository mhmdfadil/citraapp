import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '/login.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final SupabaseClient _supabase = Supabase.instance.client;
  final ScrollController _scrollController = ScrollController();
  
  late final RealtimeChannel _chatChannel;
  List<Map<String, dynamic>> _messages = [];
  late String _currentUserId;
  bool _isLoading = true;
  final String _adminId = '1';

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('id_ID').then((_) => _loadCurrentUserId());
  }

  Future<void> _loadCurrentUserId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedUserId = prefs.getString('user_id');
      
      if (savedUserId == null || savedUserId.isEmpty) {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => LoginPage()),
          );
        }
        return;
      }

      setState(() {
        _currentUserId = savedUserId;
      });

      await _initializeChat();
      _subscribeToRealtimeUpdates();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => LoginPage()),
        );
      }
    }
  }

  Future<void> _initializeChat() async {
    try {
      final response = await _supabase
          .from('chats')
          .select()
          .or('sender.eq.$_currentUserId,recipient.eq.$_currentUserId')
          .order('created_at', ascending: true);

      if (mounted) {
        setState(() {
          _messages = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    final now = DateTime.now();
    final formattedDate = DateFormat('dd MMMM yyyy', 'id_ID').format(now);
    final formattedTime = DateFormat('HH:mm', 'id_ID').format(now);

    try {
      final response = await _supabase.from('chats').insert({
        'sender': _currentUserId,
        'recipient': _adminId,
        'message': text,
        'date': formattedDate,
        'time': formattedTime,
        'created_at': now.toIso8601String(),
      }).select();

      if (mounted && response != null) {
        setState(() {
          _messages.add(response.first as Map<String, dynamic>);
        });
        _scrollToBottom();
      }
      _messageController.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Send failed: ${e.toString()}')),
        );
      }
    }
  }

  Widget _buildWelcomeMessage() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.only(bottom: 8),
        constraints: const BoxConstraints(maxWidth: 280),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Halo! Selamat datang di Citra Cosmetic',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.purple,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Terima kasih telah menghubungi kami. Ada yang bisa kami bantu?',
              style: TextStyle(color: Colors.black87),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> message, bool isSameSenderAsPrevious, bool isSameDateAsPrevious) {
    final isMe = message['sender'] == _currentUserId;

    return Column(
      crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        if (!isSameDateAsPrevious)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(message['date'] ?? ''),
              ),
            ),
          ),
        Row(
          mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isMe && !isSameSenderAsPrevious)
              const Padding(
                padding: EdgeInsets.only(right: 8),
                child: CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.purple,
                  child: Icon(Icons.store, size: 18, color: Colors.white),
                ),
              ),
            if (!isMe && isSameSenderAsPrevious)
              const SizedBox(width: 40), // Space for avatar when same sender
            
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                margin: const EdgeInsets.symmetric(vertical: 4),
                constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                decoration: BoxDecoration(
                  color: isMe ? Colors.purple[400] : Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: Radius.circular(isMe ? 16 : 4),
                    bottomRight: Radius.circular(isMe ? 4 : 16),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 5,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  children: [
                    Text(
                      message['message'] ?? '',
                      style: TextStyle(
                        fontSize: 15,
                        color: isMe ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          message['time'] ?? '',
                          style: TextStyle(
                            fontSize: 11,
                            color: isMe ? Colors.white70 : Colors.grey[600],
                          ),
                        ),
                        if (isMe)
                          const Padding(
                            padding: EdgeInsets.only(left: 4),
                            child: Icon(Icons.done_all, size: 14, color: Colors.white70),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            if (isMe && !isSameSenderAsPrevious)
              const Padding(
                padding: EdgeInsets.only(left: 8),
                child: CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.grey,
                  child: Icon(Icons.person, size: 18, color: Colors.white),
                ),
              ),
            if (isMe && isSameSenderAsPrevious)
              const SizedBox(width: 40), // Space for avatar when same sender
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Group messages by date
    final groupedMessages = <String, List<Map<String, dynamic>>>{};
    for (var msg in _messages) {
      final date = msg['date'] ?? DateFormat('dd MMMM yyyy', 'id_ID').format(DateTime.now());
      groupedMessages.putIfAbsent(date, () => []).add(msg);
    }
    
    // Sort each group by created_at
    groupedMessages.forEach((key, value) {
      value.sort((a, b) => (a['created_at'] as String).compareTo(b['created_at'] as String));
    });

    // Flatten the grouped messages into a single list with date markers
    final List<Widget> messageWidgets = [];
    
    // Always show welcome message at the top
    messageWidgets.add(_buildWelcomeMessage());
    
    // Process each date group
    groupedMessages.forEach((date, messages) {
      for (int i = 0; i < messages.length; i++) {
        final message = messages[i];
        final isSameDateAsPrevious = i > 0 && messages[i-1]['date'] == message['date'];
        final isSameSenderAsPrevious = i > 0 && messages[i-1]['sender'] == message['sender'];
        
        messageWidgets.add(
          _buildMessageBubble(message, isSameSenderAsPrevious, isSameDateAsPrevious),
        );
      }
    });

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

          // Chat content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : Container(
                    color: Colors.grey[50],
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      child: Column(
                        children: messageWidgets,
                      ),
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
    return ActionChip(
      label: Text(text),
      onPressed: () => _sendMessage(text),
      backgroundColor: Colors.white,
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _subscribeToRealtimeUpdates() {
    _chatChannel = _supabase.channel('public:chats')
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'chats',
        callback: (payload) {
          if (payload.eventType == 'INSERT') {
            final newMessage = payload.newRecord;
            if ((newMessage['sender'] == _currentUserId || 
                newMessage['recipient'] == _currentUserId)) {
              if (mounted) {
                setState(() {
                  _messages.add(newMessage);
                });
                _scrollToBottom();
              }
            }
          }
        },
      ).subscribe();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _supabase.removeChannel(_chatChannel);
    super.dispose();
  }
}