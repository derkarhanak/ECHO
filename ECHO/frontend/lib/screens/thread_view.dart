import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;

class ThreadView extends StatefulWidget {
  final VoidCallback onLetFade;
  final String? initialMessage;
  final Function(String) onSendReply; // New callback

  const ThreadView({
    super.key, 
    required this.onLetFade, 
    this.initialMessage,
    required this.onSendReply,
  });

  @override
  State<ThreadView> createState() => _ThreadViewState();
}

class _ThreadViewState extends State<ThreadView> {
  late List<String> _messages;
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _messages = [widget.initialMessage ?? "The void is silent."];
  }

  void _addMessage(String text) {
    if (text.trim().isEmpty) return;
    HapticFeedback.lightImpact();
    
    // Optimistic UI update
    setState(() {
      _messages.add(text);
      _inputController.clear();
    });
    
    // Send to backend
    widget.onSendReply(text);

    // Auto scroll to bottom
    Future.delayed(const Duration(milliseconds: 100), () {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(35),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: Container(
              width: screenSize.width * 0.88,
              height: screenSize.height * 0.7,
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 35),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(35),
                border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 40,
                    spreadRadius: 10,
                  )
                ],
              ),
              child: Column(
                children: [
                  // Header from Design
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GestureDetector(
                        onTap: widget.onLetFade,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          color: Colors.transparent,
                          child: const Icon(Icons.close, color: Colors.white24, size: 18),
                        ),
                      ),
                      const Text(
                        "E C H O", 
                        style: TextStyle(
                          color: Colors.white70, 
                          fontSize: 14, 
                          letterSpacing: 10,
                          fontWeight: FontWeight.w300,
                        )
                      ),
                      const SizedBox(width: 34), // visual balance
                    ],
                  ),
                  const SizedBox(height: 40),
                  
                  // Message History
                  Expanded(
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.only(bottom: 20),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        bool isLast = index == _messages.length - 1;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          child: Text(
                            _messages[index],
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: isLast ? 0.9 : 0.4),
                              fontSize: 18,
                              fontWeight: FontWeight.w100,
                              fontFamily: 'Georgia',
                              height: 1.6,
                              shadows: isLast ? [
                                Shadow(color: Colors.white.withValues(alpha: 0.3), blurRadius: 15)
                              ] : [],
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  const Divider(color: Colors.white10, height: 1),
                  
                  // Typing Input (Integrated based on theme)
                  Padding(
                    padding: const EdgeInsets.only(top: 20),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _inputController,
                            onSubmitted: _addMessage,
                            style: const TextStyle(
                              color: Colors.white, 
                              fontSize: 16, 
                              fontWeight: FontWeight.w200,
                              fontStyle: FontStyle.italic,
                            ),
                            decoration: InputDecoration(
                              hintText: "whisper back...",
                              hintStyle: TextStyle(
                                color: Colors.white.withValues(alpha: 0.1),
                                fontStyle: FontStyle.italic,
                              ),
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => _addMessage(_inputController.text),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.08),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                            ),
                            child: const Icon(
                              Icons.north_east_rounded, 
                              color: Colors.white38, 
                              size: 16
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
