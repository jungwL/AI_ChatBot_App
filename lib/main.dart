import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:developer';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:url_launcher/url_launcher.dart';




void main() async{
  await dotenv.load(fileName: ".env"); //앱 초기 실행시 .env 파일 로드
  runApp(const GenerativeAiApp());
}

String? _apiKey = dotenv.env['GEMINI_API_KEY'];

class GenerativeAiApp extends StatelessWidget {
  const GenerativeAiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '국립중앙박물관 챗봇',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const ChatScreen(),
    );
  }
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late final GenerativeModel _model;
  late ChatSession _chat;
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;

  final List<({String? text, bool fromUser})> _messages = [];

  Future<void> _handleRefresh() async {
    setState(() {
      print("🔃🔃새로고침 함수 실행🔃🔃");
      _messages.clear();
      _chat = _model.startChat();
      _messages.add((
      text:
      '안녕하세요! 국립중앙박물관 챗봇입니다.\n무엇을 도와드릴까요?\n\n아래 버튼을 눌러보거나, 궁금한 점을 직접 입력해보세요.',
      fromUser: false,
      ));
      _isLoading = false;
    });
    return;
  }
  @override
  void initState() {
    super.initState();

    _model = GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: _apiKey!,
      systemInstruction: Content.text( // 페르소나 설정
          """
        당신은 '국립중앙박물관'의 전문 도슨트(안내원)입니다.
        항상 친절하고 예의 바른 말투로 대답해주세요.
        주어진 [참고자료]를 바탕으로만 대답해야 합니다.
        """
      ),
    );
    _chat = _model.startChat();

    //  1. (요청 1) 앱 시작 시 첫 인사말
    _messages.add((
    text:
    '안녕하세요! 국립중앙박물관 챗봇입니다.\n무엇을 도와드릴까요?\n\n아래 버튼을 눌러보거나, 궁금한 점을 직접 입력해보세요.',
    fromUser: false,
    ));
  }

  // assets/ 파일을 읽어오는 함수
  Future<String> _getMuseumGuide() async {
    try {
      final String guideContent =
      await rootBundle.loadString('assets/national_museum_guide.txt');
      return guideContent;
    } catch (e) {
      debugPrint("오류: national_museum_guide.txt 파일을 불러올 수 없습니다. $e");
      return "오류: 안내 파일을 찾을 수 없습니다.";
    }
  }

  // 2. (요청 2) 메시지 요청 메서드
  Future<void> _sendMessage([String? presetMessage]) async {
    // 버튼을 눌렀으면 presetMessage를 사용, 아니면 텍스트필드 값을 사용
    final message = presetMessage ?? _textController.text.trim();
    if (message.isEmpty) return;

    setState(() {
      _messages.add((text: message, fromUser: true));
      _isLoading = true;
    });

    _textController.clear(); //  버튼을 눌러도 텍스트 필드는 비워줌
    _scrollToBottom();

    try {
      final String museumGuide = await _getMuseumGuide();

      final String prompt = """
      [참고자료]
      $museumGuide
      
      [사용자 질문]
      $message
      
      [지시]
      오직 [참고자료]의 내용만을 바탕으로 [사용자 질문]에 대답하세요.
      자료에 없는 내용은 "제가 가진 안내 정보에 없는 내용이라 답변하기 어렵습니다."라고 말하세요.
      링크로 답변을 하는 경우 괄호()안에 링크를 넣지말고 링크만 넣어서 답변하세요.
      답변하기 어렵거나 [참고자료]에 없는 내용은 국립중앙박물관  공식 홈페이지 URL로 제공하세요.
      """;
      print('**Ⓜ️ 사용자 질문 : $message');
      final response = await _chat.sendMessage(Content.text(prompt));

      final text = response.text;
      print('**✅ 챗봇 답장 : $text');
      if (text == null) {
        throw Exception('Gemini로부터 텍스트 응답을 받지 못했습니다.');
      }

      setState(() {
        _messages.add((text: text, fromUser: false));
        _isLoading = false;
      });
      _scrollToBottom();
    } catch (e) {
      debugPrint('오류 발생: $e');
      setState(() {
        _messages.add((text: '고객님의 네트워크가 불안정합니다. 새로고침 후 다시 이용해주세요: $e', fromUser: false));
        _isLoading = false;
      });
      _scrollToBottom();
    }
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

  //  3. (요청 2) 추천 질문 버튼 위젯
  Widget _buildSuggestionChips() {
    final suggestions = ['관람료', '입장 시간', '기본 정보', '주차 안내','현재 전시','기념품','오시는 길','편의시설'];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: Wrap(
        spacing: 8.0, // 버튼 사이 가로 간격
        runSpacing: 4.0, // 버튼 줄 사이 세로 간격
        children: suggestions.map((text) {
          return ActionChip(
            label: Text(text),
            onPressed: () {
              //  4. (요청 2) 버튼의 텍스트를 _sendMessage로 전달
              _sendMessage(text);
            },
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18.0),
              side: BorderSide(color: Theme.of(context).colorScheme.outline),
            ),
            backgroundColor: Theme.of(context).colorScheme.surface,
          );
        }).toList(),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('[국립중앙박물관 챗봇]'),
      ),
      body: Column(
        children: [
          // 1. 채팅 메시지 목록 (ListView)
          Expanded(
            child: RefreshIndicator(
              onRefresh: _handleRefresh,
              child: ListView.builder(
                controller: _scrollController,
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  if (index >= _messages.length) {
                    return Container();
                  }
                  final message = _messages[index];
                  return MessageBubble(
                    text: message.text ?? '...',
                    isFromUser: message.fromUser,
                  );
                },
              ),
            ),
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: Row(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(width: 10),
                  Text('박물관 정보를 찾는 중입니다...'),
                ],
              ),
            ),

          //  5. (요청 2) 추천 버튼 영역 추가
          _buildSuggestionChips(),

          // 2. 하단 텍스트 입력창
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    decoration: InputDecoration(
                      hintText: '궁금한 점을 물어보세요',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25.0),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                    ),
                    //  6. (요청 2) 엔터키 전송 시 _sendMessage() 호출
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send),
                  //  7. (요청 2) 전송 버튼 클릭 시 _sendMessage() 호출
                  onPressed: () => _sendMessage(),
                  style: IconButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
class MessageBubble extends StatelessWidget {
  final String text;
  final bool isFromUser;

  const MessageBubble({
    super.key,
    required this.text,
    required this.isFromUser,
  });

  Future<void> _openLink(LinkableElement link) async {
    final uri = Uri.parse(link.url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Align(
        alignment: isFromUser ? Alignment.centerRight : Alignment.centerLeft,
        child: Row( //  Row 위젯 추가
          mainAxisAlignment: isFromUser ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isFromUser)
              Padding(
                padding: const EdgeInsets.only(right: 8.0, top: 4.0),
                child: Icon(
                  Icons.smart_toy_outlined,
                  color: theme.colorScheme.secondary,
                  size: 24,
                ),
              ),
            Flexible(
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.75,
                ),
                decoration: BoxDecoration(
                  color: isFromUser
                      ? theme.colorScheme.primaryContainer
                      : theme.colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                child: Linkify(
                  onOpen: _openLink,
                  text: text,
                  style: theme.textTheme.bodyMedium,
                  linkStyle: TextStyle(
                    color: Colors.blue,
                    decoration: TextDecoration.underline,
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