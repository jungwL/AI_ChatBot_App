import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:developer';
import 'package:flutter_linkify/flutter_linkify.dart'; // import 확인
import 'package:url_launcher/url_launcher.dart';    // import 확인


const String _apiKey = "APi 키값";

void main() {
  runApp(const GenerativeAiApp());
}

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
  late final ChatSession _chat;
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;

  final List<({String? text, bool fromUser})> _messages = [];

  @override
  void initState() {
    super.initState();

    _model = GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: _apiKey,
      systemInstruction: Content.text(
          """
        당신은 '국립중앙박물관'의 전문 도슨트(안내원)입니다.
        항상 친절하고 예의 바른 말투로 대답해주세요.
        주어진 [참고 자료]를 바탕으로만 대답해야 합니다.
        """
      ),
    );
    _chat = _model.startChat();

    //  1. (요청 1) 앱 시작 시 첫 인사말 추가
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

  // 👈 2. (요청 2) _sendMessage가 버튼 입력을 받을 수 있도록 수정
  Future<void> _sendMessage([String? presetMessage]) async {
    // 버튼을 눌렀으면 presetMessage를 사용, 아니면 텍스트필드 값을 사용
    final message = presetMessage ?? _textController.text.trim();
    if (message.isEmpty) return;

    setState(() {
      _messages.add((text: message, fromUser: true));
      _isLoading = true;
    });

    _textController.clear(); // 👈 버튼을 눌러도 텍스트 필드는 비워줌
    _scrollToBottom();

    try {
      final String museumGuide = await _getMuseumGuide();

      final String prompt = """
      [참고 자료]
      $museumGuide

      [사용자 질문]
      $message

      [지시]
      오직 [참고 자료]의 내용만을 바탕으로 [사용자 질문]에 대답하세요.
      자료에 없는 내용은 "제가 가진 안내 정보에 없는 내용이라 답변하기 어렵습니다."라고 말하세요.
      """;

      final response = await _chat.sendMessage(Content.text(prompt));

      final text = response.text;
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
        _messages.add((text: '오류 발생: $e', fromUser: false));
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

  // 👈 3. (요청 2) 추천 질문 버튼 위젯 (신규 추가)
  Widget _buildSuggestionChips() {
    // 여기에 표시하고 싶은 질문 버튼들을 넣으세요.
    final suggestions = ['관람료', '입장 시간', '기본 정보', '주차 안내','현재 전시','기념품','오시는 길','편의시설'];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      // Wrap: 버튼이 많아지면 자동으로 다음 줄로 넘겨줍니다.
      child: Wrap(
        spacing: 8.0, // 버튼 사이 가로 간격
        runSpacing: 4.0, // 버튼 줄 사이 세로 간격
        children: suggestions.map((text) {
          return ActionChip(
            label: Text(text),
            onPressed: () {
              // 👈 4. (요청 2) 버튼의 텍스트를 _sendMessage로 전달
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
        title: const Text('국립중앙박물관 챗봇'),
      ),
      body: Column(
        children: [
          // 1. 채팅 메시지 목록 (ListView)
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                return MessageBubble(
                  text: message.text ?? '...',
                  isFromUser: message.fromUser,
                );
              },
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
                    //  6. (요청 2) 엔터키 전송 시 _sendMessage() 호출 (인수 없음)
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send),
                  //  7. (요청 2) 전송 버튼 클릭 시 _sendMessage() 호출 (인수 없음)
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

// (채팅 버블 위젯은 변경 없음)
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
        child: Row( //  Row 위젯 추가 (아이콘과 버블을 나란히 배치)
          mainAxisAlignment: isFromUser ? MainAxisAlignment.end : MainAxisAlignment.start, //  정렬 변경
          crossAxisAlignment: CrossAxisAlignment.start, //  상단 정렬
          children: [
            // 챗봇 메시지일 때 로봇 아이콘 표시
            if (!isFromUser)
              Padding(
                padding: const EdgeInsets.only(right: 8.0, top: 4.0), //  버블과의 간격 조절
                child: Icon(
                  Icons.smart_toy_outlined, //  로봇 아이콘 (원하는 다른 아이콘으로 변경 가능)
                  color: theme.colorScheme.secondary,
                  size: 24, //  아이콘 크기
                ),
              ),
            Flexible( //  메시지 버블이 남은 공간을 차지하도록 Flexible 추가
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
                  onOpen: _openLink, // (2번에서 추가한 함수) 링크 클릭 시 실행
                  text: text,
                  style: theme.textTheme.bodyMedium, // 기본 텍스트 스타일
                  linkStyle: TextStyle( // 링크 스타일
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