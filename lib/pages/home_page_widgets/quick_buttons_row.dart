import 'package:entry/entry.dart';
import 'package:fluent_gpt/common/prefs/app_cache.dart';
import 'package:fluent_gpt/i18n/i18n.dart';
import 'package:fluent_gpt/providers/chat_provider.dart';
import 'package:fluent_gpt/utils.dart';
import 'package:fluent_gpt/widgets/wiget_constants.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shimmer_animation/shimmer_animation.dart';

class QuickHelperButtonsFromLLMRow extends StatelessWidget {
  const QuickHelperButtonsFromLLMRow({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ChatProvider>();
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Wrap(
          spacing: 4,
          runSpacing: 2,
          children: [
            if (provider.isGeneratingQuestionHelpers)
              Shimmer(
                color: context.theme.accentColor,
                duration: const Duration(milliseconds: 500),
                child: SizedBox(
                  width: MediaQuery.sizeOf(context).width,
                  height: 32,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Container(
                        width: 100,
                        height: 32,
                        decoration: const BoxDecoration(
                          color: Color.fromARGB(255, 197, 197, 197),
                          borderRadius: BorderRadius.all(Radius.circular(8)),
                        ),
                        margin: const EdgeInsets.only(right: 8),
                      ),
                      Container(
                        width: 100,
                        height: 32,
                        decoration: const BoxDecoration(
                          color: Color.fromARGB(255, 197, 197, 197),
                          borderRadius: BorderRadius.all(Radius.circular(8)),
                        ),
                        margin: const EdgeInsets.only(right: 8),
                      ),
                      Container(
                        width: 100,
                        height: 32,
                        decoration: const BoxDecoration(
                          color: Color.fromARGB(255, 197, 197, 197),
                          borderRadius: BorderRadius.all(Radius.circular(8)),
                        ),
                        margin: const EdgeInsets.only(right: 8),
                      ),
                      Container(
                        width: 100,
                        height: 32,
                        decoration: const BoxDecoration(
                          color: Color.fromARGB(255, 197, 197, 197),
                          borderRadius: BorderRadius.all(Radius.circular(8)),
                        ),
                        margin: const EdgeInsets.only(right: 8),
                      ),
                    ],
                  ),
                ),
                // child: Container(
                //   height: 32,
                //   width: MediaQuery.sizeOf(context).width,
                //   color: Colors.blue,
                // ),
              ),
            if (AppCache.enableQuestionHelpers.value == null)
              Tooltip(
                style: TooltipThemeData(waitDuration: const Duration(milliseconds: 200)),
                richMessage: WidgetSpan(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          'Will ask AI to produce buttons for each response. It will consume additional tokens in order to generate suggestions'
                              .tr),
                      spacer,
                      Image.asset('assets/im_suggestions_tip.png'),
                    ],
                  ),
                ),
                child: SizedBox(
                  width: MediaQuery.sizeOf(context).width,
                  child: InfoBar(
                    title: Row(
                      children: [
                        Expanded(child: Text('Do you want to enable suggestion helpers?'.tr)),
                        FilledButton(
                          onPressed: () {
                            AppCache.enableQuestionHelpers.value = true;
                            provider.updateUI();
                          },
                          child: Text('Enable'.tr),
                        ),
                        Button(
                          onPressed: () {
                            AppCache.enableQuestionHelpers.value = false;
                            provider.updateUI();
                          },
                          child: Text('No. Don\'t show again'.tr),
                        )
                      ],
                    ),
                  ),
                ),
              ),
            for (final item in provider.questionHelpers)
              Entry.all(
                curve: Curves.decelerate,
                xOffset: 100,
                child: Button(
                  style: ButtonStyle(
                    padding: WidgetStateProperty.all(
                      EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    ),
                  ),
                  onPressed: () async {
                    final clipboard = await Clipboard.getData(Clipboard.kTextPlain);
                    provider.sendMessage(item.getPromptText(clipboard?.text));
                  },
                  child: Text(item.title.tr, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
