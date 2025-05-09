import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '/login.dart';
import '/screens/content/cart_screen.dart';
import '/screens/content/emoji_data.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  final SupabaseClient _supabase = Supabase.instance.client;
  
  String? _currentUserId;
  String? _selectedAdminId;
  List<Map<String, dynamic>> _adminList = [];
  List<Map<String, dynamic>> _filteredAdminList = [];
  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;
  bool _isFirstLoad = true;
  RealtimeChannel? _messagesChannel;
  RealtimeChannel? _adminStatusChannel;
  bool _showChatContent = false;
  bool _showEmojiPicker = false;
  String? _selectedEmojiCategory;
  bool _isScrolling = false;
  Map<String, int> _unreadCounts = {};

  // Luxury pink color palette
  final Color _primaryColor = const Color(0xFFE91E63);
  final Color _secondaryColor = const Color(0xFFF8BBD0);
  final Color _accentColor = const Color(0xFFFF4081);
  final Color _lightPink = const Color(0xFFFCE4EC);
  final Color _darkPink = const Color(0xFFC2185B);
  final Color _textColor = Colors.white;
  final Color _chatBubbleUser = const Color(0xFFF06292);
  final Color _chatBubbleAdmin = const Color.fromARGB(255, 255, 141, 181);

  @override
  void initState() {
    super.initState();
    EmojiData.initialize();
    _selectedEmojiCategory = 'All';
    _searchController.addListener(_filterAdminList);
    _scrollController.addListener(_handleScroll);
    initializeDateFormatting('id_ID').then((_) => _loadCurrentUser());
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _searchController.dispose();
    _messagesChannel?.unsubscribe();
    _adminStatusChannel?.unsubscribe();
    super.dispose();
  }

  void _handleScroll() {
    if (_scrollController.position.pixels == _scrollController.position.maxScrollExtent) {
      if (!_isScrolling) {
        _isScrolling = true;
        _markMessagesAsRead();
      }
    } else {
      _isScrolling = false;
    }
  }

  void _filterAdminList() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredAdminList = _adminList.where((admin) {
        final username = admin['username'].toString().toLowerCase();
        return username.contains(query);
      }).toList();
    });
  }

  Future<void> _loadCurrentUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _currentUserId = prefs.getString('user_id')?.toString();
      if (_currentUserId == null) {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => LoginPage()),
          );
        }
        return;
      }
      await _fetchAdminList();
      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memuat pengguna: $e')),
        );
      }
    }
  }

  Future<void> _fetchAdminList() async {
  try {
    // First, get all admins
    final adminResponse = await _supabase
        .from('users')
        .select('id, username, roles, avatar_url')
        .eq('roles', 'Admin')
        .order('username', ascending: true);

    if (adminResponse.isEmpty) {
      if (mounted) {
        setState(() {
          _adminList = [];
          _filteredAdminList = [];
        });
      }
      return;
    }

    // For each admin, find their latest chat
    List<Map<String, dynamic>> adminsWithLastChat = [];

    for (var admin in adminResponse) {
      final adminId = admin['id'];

      // Find the latest chat where admin is sender or recipient
      final lastChatResponse = await _supabase
          .from('chats')
          .select('created_at, message')
          .or('sender_id.eq.$adminId,recipient_id.eq.$adminId')
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      String lastMessage = lastChatResponse?['message'] ?? '';
      DateTime? lastMessageTime;
      
      if (lastChatResponse != null && lastChatResponse['created_at'] != null) {
        try {
          dynamic createdAt = lastChatResponse['created_at'];
          
          if (createdAt is DateTime) {
            lastMessageTime = createdAt;
          } else if (createdAt is String) {
            lastMessageTime = DateTime.tryParse(createdAt);
          }
        } catch (e) {
          debugPrint('Error parsing date: $e');
          lastMessageTime = null;
        }
      }

      adminsWithLastChat.add({
        ...admin,
        'id': adminId.toString(),
        'last_message': lastMessage,
        'last_message_time': lastMessageTime?.toIso8601String(),
      });
    }

    // Check if any admin has messages
    final anyAdminHasMessages = adminsWithLastChat.any((admin) => admin['last_message_time'] != null);
    
    // Check if all admins have messages
    final allAdminsHaveMessages = adminsWithLastChat.every((admin) => admin['last_message_time'] != null);

    // Sort admins based on conditions
    adminsWithLastChat.sort((a, b) {
      // Case 1: No admins have messages - sort by username
      if (!anyAdminHasMessages) {
        return (a['username'] as String).compareTo(b['username'] as String);
      }
      
      // Case 2: Some admins have messages
      final aHasMessage = a['last_message_time'] != null;
      final bHasMessage = b['last_message_time'] != null;
      
      // If one has message and other doesn't, the one with message comes first
      if (aHasMessage && !bHasMessage) return -1;
      if (!aHasMessage && bHasMessage) return 1;
      
      // If both have messages, sort by message time (newest first)
      if (aHasMessage && bHasMessage) {
        return (b['last_message_time'] as String).compareTo(a['last_message_time'] as String);
      }
      
      // If neither has messages, sort by username
      return (a['username'] as String).compareTo(b['username'] as String);
    });

    if (mounted) {
      setState(() {
        _adminList = adminsWithLastChat;
        _filteredAdminList = List.from(_adminList);
        
        // Initialize unread counts
        for (var admin in _adminList) {
          _unreadCounts[admin['id']] = 0;
        }
        
        _loadLastMessagesAndUnreadCounts();
        _setupAdminStatusSubscription();
      });
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memuat daftar admin: $e')),
      );
    }
  }
}

  void _setupAdminStatusSubscription() {
    _adminStatusChannel?.unsubscribe();
    
    _adminStatusChannel = _supabase
        .channel('admin_status_updates')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'chats',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.neq,
            column: 'sender_id',
            value: _currentUserId,
          ),
          callback: (payload) {
            _loadLastMessagesAndUnreadCounts();
          },
        )
        .subscribe();
  }

  Future<void> _loadLastMessagesAndUnreadCounts() async {
    if (_currentUserId == null) return;

    try {
      for (var admin in _adminList) {
        // Get last message
        final lastMessageResponse = await _supabase
            .from('chats')
            .select('message, created_at, is_read, sender_id')
            .or('sender_id.eq.$_currentUserId,recipient_id.eq.$_currentUserId')
            .or('sender_id.eq.${admin['id']},recipient_id.eq.${admin['id']}')
            .order('created_at', ascending: false)
            .limit(1);

        if (lastMessageResponse.isNotEmpty) {
          final lastMessage = lastMessageResponse[0];
          admin['last_message'] = _convertUnicodeToEmoji(lastMessage['message']);
          admin['last_message_time'] = lastMessage['created_at'];
        }

        // Get unread count
        final unreadResponse = await _supabase
            .from('chats')
            .select('id')
            .eq('recipient_id', _currentUserId as Object)
            .eq('sender_id', admin['id'])
            .eq('is_read', false);

        final unreadCount = unreadResponse.length;
        _unreadCounts[admin['id']] = unreadCount;
      }

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memuat pesan terakhir: $e')),
        );
      }
    }
  }

  void _setupMessagesSubscription() {
    if (_selectedAdminId == null || _currentUserId == null) return;

    _messagesChannel?.unsubscribe();

    _messagesChannel = _supabase
        .channel('public:chats')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'chats',
          callback: (payload) {
            _fetchMessages();
            _loadLastMessagesAndUnreadCounts();
            _fetchAdminList(); 
          },
        )
        .subscribe();

    _fetchMessages();
  }

  Future<void> _fetchMessages() async {
    if (_selectedAdminId == null || _currentUserId == null) return;

    try {
      final response = await _supabase
          .from('chats')
          .select('*')
          .or('sender_id.eq.$_currentUserId,recipient_id.eq.$_currentUserId')
          .or('sender_id.eq.$_selectedAdminId,recipient_id.eq.$_selectedAdminId')
          .order('created_at', ascending: true);

      if (mounted) {
        setState(() {
          _messages = List<Map<String, dynamic>>.from(response);
          _messages = _messages.map((msg) {
            return {
              ...msg,
              'id': msg['id'].toString(),
              'sender_id': msg['sender_id'].toString(),
              'recipient_id': msg['recipient_id'].toString(),
              'message': _convertUnicodeToEmoji(msg['message']),
            };
          }).toList();
          _isFirstLoad = false;
        });
        _markMessagesAsRead();
      }

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memuat pesan: $e')),
        );
      }
    }
  }

  String _convertEmojiToUnicode(String text) {
    return text.runes.map((rune) => '\\u{${rune.toRadixString(16)}}').join();
  }

  String _convertUnicodeToEmoji(String text) {
    return text.replaceAllMapped(
      RegExp(r'\\u\{([0-9a-fA-F]+)\}'),
      (Match m) => String.fromCharCode(int.parse(m.group(1)!, radix: 16)),
    );
  }

  Future<void> _markMessagesAsRead() async {
  if (_selectedAdminId == null || _currentUserId == null) return;

  try {
    final unreadMessages = _messages.where((msg) =>
        msg['sender_id'] == _selectedAdminId && 
        msg['recipient_id'] == _currentUserId && 
        msg['is_read'] == false).toList();

    if (unreadMessages.isNotEmpty) {
      final unreadIds = unreadMessages.map((msg) => msg['id']).toList();
      
      // Update messages as read in database
      final response = await _supabase
          .from('chats')
          .update({'is_read': true})
          .in_('id', unreadIds);

      if (response.error != null) {
        throw response.error!;
      }
      
      // Update local state to reflect read status
      if (mounted) {
        setState(() {
          for (var msg in _messages) {
            if (unreadIds.contains(msg['id'])) {
              msg['is_read'] = true;
            }
          }
          
          // Update unread count
          _unreadCounts[_selectedAdminId!] = 0;
        });
      }
    }
  } catch (e) {
    if (mounted) {
     
    }
  }
}

  Future<void> _sendMessage() async {
    final messageText = _messageController.text.trim();
    if (messageText.isEmpty || _selectedAdminId == null || _currentUserId == null) return;

    try {
      final messageToSend = _convertEmojiToUnicode(messageText);
      
      await _supabase.from('chats').insert({
        'sender_id': _currentUserId,
        'recipient_id': _selectedAdminId,
        'message': messageToSend,
        'is_read': false,
        'created_at': DateTime.now().toIso8601String(),
      });

      _messageController.clear();

       await _fetchAdminList();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengirim pesan: $e')),
        );
      }
    }
  }

  void _selectAdmin(String adminId) {
    setState(() {
      _selectedAdminId = adminId.toString();
      _messages = [];
      _isFirstLoad = true;
      if (_isMobile()) {
        _showChatContent = true;
      }
    });
    _setupMessagesSubscription();
  }

  Widget _buildMessageBubble(Map<String, dynamic> message, int index) {
    final isCurrentUser = message['sender_id'] == _currentUserId;
    final messageDate = DateTime.parse(message['created_at']);
    final timeFormat = DateFormat('HH:mm');
    final dateFormat = DateFormat('EEEE, d MMMM y', 'id_ID');

    bool showDateHeader = false;
    if (index == 0) {
      showDateHeader = true;
    } else {
      final previousMessageDate = DateTime.parse(_messages[index - 1]['created_at']);
      showDateHeader = !_isSameDay(messageDate, previousMessageDate);
    }

    return Column(
      crossAxisAlignment: isCurrentUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        if (showDateHeader)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: _lightPink,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.pink.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  dateFormat.format(messageDate),
                  style: TextStyle(
                    color: _darkPink,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4),
          child: Row(
            mainAxisAlignment: isCurrentUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isCurrentUser)
                CircleAvatar(
                  radius: 16,
                  backgroundColor: _secondaryColor,
                  backgroundImage: _adminList.isNotEmpty && 
                      _adminList.firstWhere((admin) => admin['id'] == message['sender_id'])['avatar_url'] != null
                      ? NetworkImage(_adminList.firstWhere((admin) => admin['id'] == message['sender_id'])['avatar_url'])
                      : null,
                  child: _adminList.isNotEmpty && 
                      _adminList.firstWhere((admin) => admin['id'] == message['sender_id'])['avatar_url'] == null
                      ? Icon(Icons.person, size: 16, color: _textColor)
                      : null,
                ),
              const SizedBox(width: 8),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isCurrentUser ? _chatBubbleUser : _chatBubbleAdmin,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(20),
                      topRight: const Radius.circular(20),
                      bottomLeft: Radius.circular(isCurrentUser ? 20 : 4),
                      bottomRight: Radius.circular(isCurrentUser ? 4 : 20),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.pink.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!isCurrentUser)
                        Text(
                          _adminList.isNotEmpty 
                              ? _adminList.firstWhere((admin) => admin['id'] == message['sender_id'])['username']
                              : 'Admin',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: _darkPink,
                          ),
                        ),
                      Text(
                        message['message'],
                        style: TextStyle(
                          color: isCurrentUser ? _textColor : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            timeFormat.format(messageDate),
                            style: TextStyle(
                              fontSize: 10,
                              color: isCurrentUser ? Colors.white70 : Colors.black54,
                            ),
                          ),
                        
                            Padding(
                              padding: const EdgeInsets.only(left: 4.0),
                              child: Icon(
                                message['is_read'] ? Icons.done_all : Icons.done,
                                size: 12,
                                color: message['is_read'] ? Colors.white : Colors.white70,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
           date1.month == date2.month &&
           date1.day == date2.day;
  }

  Widget _buildEmptyChat() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.spa,
            size: 80,
            color: _primaryColor.withOpacity(0.3),
          ),
          const SizedBox(height: 20),
          Text(
            'Citra Kosmetik',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: _primaryColor,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _selectedAdminId == null 
                ? 'Pilih admin dari daftar untuk memulai percakapan'
                : 'Belum ada pesan',
            style: TextStyle(
              fontSize: 16,
              color: _darkPink,
            ),
          ),
          if (_selectedAdminId == null) ...[
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              onPressed: () {
                if (_adminList.isNotEmpty) {
                  _selectAdmin(_adminList.first['id']);
                }
              },
              child: Text(
                'Mulai Chat',
                style: TextStyle(color: _textColor),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildChatContent() {
    if (_selectedAdminId == null) {
      return _buildEmptyChat();
    }

    if (_isFirstLoad) {
      return Center(
        child: CircularProgressIndicator(
          color: _primaryColor,
        ),
      );
    }

    if (_messages.isEmpty) {
      return _buildEmptyChat();
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(8),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        return _buildMessageBubble(_messages[index], index);
      },
    );
  }

  bool _isMobile() {
    return MediaQuery.of(context).size.width < 760;
  }

  Widget _buildMobileLayout() {
    if (_showChatContent && _selectedAdminId != null) {
      return _buildChatScreen();
    } else {
      return _buildAdminList();
    }
  }

  Widget _buildWebLayout() {
    return Row(
      children: [
        // Admin List Sidebar
        Container(
          width: 300,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(right: BorderSide(color: _secondaryColor)),
            boxShadow: [
              BoxShadow(
                color: Colors.pink.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(2, 0),
              ),
            ],
          ),
          child: Column(
            children: [
              // Search Bar
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: _lightPink,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Cari...',
                      prefixIcon: Icon(Icons.search, color: _primaryColor),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: _buildAdminList(),
              ),
            ],
          ),
        ),
        // Chat Area
        Expanded(
          child: _selectedAdminId == null 
              ? _buildEmptyChat()
              : _buildChatScreen(),
        ),
      ],
    );
  }

  Widget _buildAdminList() {
    final listToShow = _searchController.text.isEmpty ? _adminList : _filteredAdminList;
    
    return ListView.builder(
      itemCount: listToShow.length,
      itemBuilder: (context, index) {
        final admin = listToShow[index];
        final lastMessageTime = admin['last_message_time'] != null 
            ? DateTime.parse(admin['last_message_time'])
            : null;
        final timeFormat = DateFormat('HH:mm');
        final unreadCount = _unreadCounts[admin['id']] ?? 0;
        
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: admin['id'] == _selectedAdminId 
                ? _primaryColor.withOpacity(0.1)
                : Colors.transparent,
          ),
          child: ListTile(
            onTap: () => _selectAdmin(admin['id'].toString()),
            leading: CircleAvatar(
              radius: 24,
              backgroundColor: _primaryColor,
              backgroundImage: admin['avatar_url'] != null
                  ? NetworkImage(admin['avatar_url'])
                  : null,
              child: admin['avatar_url'] == null
                  ? Icon(Icons.person, color: _textColor)
                  : null,
            ),
            title: Text(
              admin['username'],
              style: TextStyle(
                fontWeight: admin['id'] == _selectedAdminId 
                    ? FontWeight.bold 
                    : FontWeight.normal,
                color: _darkPink,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              admin['last_message']?.toString() ?? '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
            trailing: SizedBox(
              width: 80,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (lastMessageTime != null)
                    Text(
                      timeFormat.format(lastMessageTime),
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey,
                      ),
                    ),
                  const SizedBox(height: 4),
                  if (unreadCount > 0)
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: _primaryColor,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        unreadCount.toString(),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 8),
          ),
        );
      },
    );
  }

  Widget _buildEmojiPicker() {
    return Container(
      height: 250,
      color: _lightPink,
      child: Column(
        children: [
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: EmojiData.categories.keys.map((category) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: TextButton(
                    onPressed: () {
                      setState(() {
                        _selectedEmojiCategory = category;
                      });
                    },
                    style: TextButton.styleFrom(
                      backgroundColor: _selectedEmojiCategory == category 
                          ? _primaryColor.withOpacity(0.2) 
                          : Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: Text(
                      category,
                      style: TextStyle(
                        color: _darkPink,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(8),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 8,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
              ),
              itemCount: _selectedEmojiCategory == 'All'
                  ? EmojiData.categories['All']!.length
                  : EmojiData.categories[_selectedEmojiCategory]!.length,
              itemBuilder: (context, index) {
                final emoji = _selectedEmojiCategory == 'All'
                    ? EmojiData.categories['All']![index]
                    : EmojiData.categories[_selectedEmojiCategory]![index];
                
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _messageController.text += emoji;
                    });
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.white.withOpacity(0.5),
                    ),
                    child: Center(
                      child: Text(
                        emoji,
                        style: const TextStyle(fontSize: 24),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatScreen() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.pink.withOpacity(0.1),
            blurRadius: 16,
            offset: const Offset(-5, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          // Chat Header
          if (_selectedAdminId != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _lightPink,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.pink.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  if (_isMobile())
                    IconButton(
                      icon: Icon(Icons.arrow_back, color: _darkPink),
                      onPressed: () {
                        setState(() {
                          _showChatContent = false;
                        });
                      },
                    ),
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: _secondaryColor,
                    backgroundImage: _adminList.isNotEmpty 
                        ? _adminList.firstWhere(
                            (admin) => admin['id'] == _selectedAdminId)['avatar_url'] != null
                            ? NetworkImage(_adminList.firstWhere(
                                (admin) => admin['id'] == _selectedAdminId)['avatar_url'])
                            : null
                        : null,
                    child: _adminList.isNotEmpty 
                        ? _adminList.firstWhere(
                            (admin) => admin['id'] == _selectedAdminId)['avatar_url'] == null
                            ? Icon(Icons.person, size: 20, color: _textColor)
                            : null
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _selectedAdminId != null && _adminList.isNotEmpty
                            ? _adminList.firstWhere(
                                (admin) => admin['id'] == _selectedAdminId)['username']
                            : 'Admin',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: _darkPink,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          // Messages List
          Expanded(
            child: _buildChatContent(),
          ),
          // Emoji Picker
          if (_showEmojiPicker) _buildEmojiPicker(),
          // Message Input
          if (_selectedAdminId != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _lightPink,
                border: Border(
                  top: BorderSide(color: _secondaryColor)),
                ),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(
                      _showEmojiPicker ? Icons.keyboard : Icons.emoji_emotions_outlined,
                      color: _primaryColor,
                    ),
                    onPressed: () {
                      setState(() {
                        _showEmojiPicker = !_showEmojiPicker;
                      });
                    },
                  ),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.pink.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _messageController,
                        decoration: InputDecoration(
                          hintText: 'Ketik pesan...',
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 16),
                        ),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _primaryColor,
                      boxShadow: [
                        BoxShadow(
                          color: _primaryColor.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.send, color: Colors.white),
                      onPressed: _sendMessage,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _lightPink,
      appBar: AppBar(
        title: const Text('Citra Kosmetik', style: TextStyle(color: Colors.white)),
        centerTitle: false,
        backgroundColor: const Color(0xFFF273F0),
        elevation: 10,
        shadowColor: _primaryColor.withOpacity(0.5),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(20),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => CartContent()),
            );
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () async {
              await _supabase.auth.signOut();
              if (mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => LoginPage()),
                );
              }
            },
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: _secondaryColor,
              ),
            )
          : _isMobile() ? _buildMobileLayout() : _buildWebLayout(),
    );
  }
}

extension PostgrestFilterBuilderExtension on PostgrestFilterBuilder {
  PostgrestFilterBuilder in_(String column, List<dynamic> values) {
    return inFilter(column, values);
  }
}