import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_markdown/flutter_markdown.dart'; // Linkify 대신 Markdown 사용
import 'package:url_launcher/url_launcher.dart';
import 'dart:developer'; // debugPrint 대신 log 사용 시 (선택 사항)

// .env 파일에서 API 키 가져오기
String? _apiKey = dotenv.env['GEMINI_API_KEY'];

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late final GenerativeModel _model;
  late ChatSession _chat; // 'final' 제거
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;

  final List<({String? text, bool fromUser})> _messages = [];

  Future<void> _handleRefresh() async {
    setState(() {
      print("*****************************새로고침 함수 실행**********************");
      _messages.clear();
      _chat = _model.startChat(); // final이 아니므로 새 세션 할당 가능
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

    if (_apiKey == null) {
      print("API 키가 로드되지 않았습니다. .env 파일을 확인하세요.");
      // API 키가 없을 때 사용자에게 알림
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('API 키를 불러올 수 없습니다. 앱 설정을 확인하세요.'),
            backgroundColor: Colors.red,
          ),
        );
      });
      // API 키가 없으면 모델을 초기화할 수 없으므로, 더미 모델이나 에러 처리가 필요함
      // 여기서는 일단 치명적 오류로 간주하고, 모델 초기화 시도를 막기 위해
      // 이후 로직이 비정상 동작할 수 있음을 인지해야 함.
      // 실제 앱에서는 _apiKey가 null일 때 앱을 중단시키거나
      // API 키 입력 화면으로 보내는 등의 처리가 필요.
      return;
    }

    _model = GenerativeModel(
      model: 'gemini-2.5-flash', //모델명 작성
      apiKey: _apiKey!,
      systemInstruction: Content.text("""
        당신은 '국립중앙박물관'의 전문 도슨트(안내원)입니다.
        항상 친절하고 예의 바른 말투로 대답해주세요.
        주어진 [참고자료]를 바탕으로만 대답해야 합니다.
        
        [중요] 링크를 제공할 때는 반드시 [텍스트](URL) 형식의 마크다운을 사용하세요.
        (예시: 자세한 내용은 [공식 홈페이지](https://www.museum.go.kr/)를 참고하세요.)
        """),
    );
    _chat = _model.startChat();

    //  앱 시작 시 첫 인사말 추가
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

  // _sendMessage (버튼 입력 가능)
  Future<void> _sendMessage([String? presetMessage]) async {
    if (_apiKey == null) return; // API 키 없으면 전송 불가

    final message = presetMessage ?? _textController.text.trim();
    if (message.isEmpty) return;

    setState(() {
      _messages.add((text: message, fromUser: true));
      _isLoading = true;
    });

    _textController.clear();
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

  // 추천 질문 버튼 위젯
  Widget _buildSuggestionChips() {
    final suggestions = ['관람료', '입장 시간', '기본 정보', '주차 안내','현재 전시','기념품','오시는 길','편의시설'];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: Wrap(
        spacing: 8.0,
        runSpacing: 4.0,
        children: suggestions.map((text) {
          return ActionChip(
            label: Text(text),
            onPressed: () {
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
        backgroundColor: Colors.transparent, // 배경 이미지와 어울리게
        elevation: 0,
      ),
      extendBodyBehindAppBar: true, // AppBar 뒤로 배경 확장
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: const AssetImage('assets/images/national_museum.png'),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(
              Colors.black.withOpacity(0.6),
              BlendMode.darken,
            ),
          ),
        ),
        child: Column(
          children: [
            // AppBar 높이 + 상단 상태바 높이만큼 공간 확보
            SizedBox(height: kToolbarHeight + MediaQuery.of(context).padding.top),

            Expanded(
              child: RefreshIndicator(
                onRefresh: _handleRefresh,
                child: ListView.builder(
                  controller: _scrollController,
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    // RangeError 방어 코드
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
              Container(
                color: Theme.of(context).colorScheme.surface.withOpacity(0.8),
                padding: const EdgeInsets.all(8.0),
                child: const Row(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(width: 10),
                    Text('박물관 정보를 찾는 중입니다...'),
                  ],
                ),
              ),

            // 가독성을 위해 하단 UI 영역에 반투명 배경 추가
            Container(
              color: Theme.of(context).colorScheme.surface.withOpacity(0.8),
              child: Column(
                children: [
                  _buildSuggestionChips(),
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
                              filled: true, // 입력창 배경색 채우기
                              fillColor: Theme.of(context).colorScheme.surface,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 10,
                              ),
                            ),
                            onSubmitted: (_) => _sendMessage(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.send),
                          onPressed: () => _sendMessage(),
                          style: IconButton.styleFrom(
                            backgroundColor:
                            Theme.of(context).colorScheme.primary,
                            foregroundColor:
                            Theme.of(context).colorScheme.onPrimary,
                          ),
                        ),
                      ],
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
}

// 말풍선 위젯 (flutter_markdown 사용)
class MessageBubble extends StatelessWidget {
  final String text;
  final bool isFromUser;

  const MessageBubble({
    super.key,
    required this.text,
    required this.isFromUser,
  });

  // 링크 클릭 시 브라우저 실행
  Future<void> _onTapLink(String text, String? href, String title) async {
    if (href == null) return;
    final uri = Uri.parse(href);
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
        child: Row(
          mainAxisAlignment:
          isFromUser ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isFromUser)
              Padding(
                padding: const EdgeInsets.only(right: 8.0, top: 4.0),
                child: Icon(
                  Icons.smart_toy_outlined,
                  color: Colors.teal[200],
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
                padding:
                const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                child: MarkdownBody( // Linkify 대신 MarkdownBody 사용
                  data: text,
                  onTapLink: _onTapLink, // 링크 클릭 핸들러 연결
                  styleSheet: MarkdownStyleSheet(
                    p: theme.textTheme.bodyMedium, // 일반 텍스트 스타일
                    a: TextStyle( // 링크(a 태그) 스타일
                      color: Colors.blue,
                      decoration: TextDecoration.underline,
                    ),
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