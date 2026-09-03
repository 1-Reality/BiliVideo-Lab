import 'dart:math';

import 'package:PiliBro/common/assets.dart';
import 'package:PiliBro/common/constants.dart';
import 'package:PiliBro/common/style.dart';
import 'package:PiliBro/common/widgets/badge.dart';
import 'package:PiliBro/common/widgets/custom_icon.dart';
import 'package:PiliBro/common/widgets/dialog/dialog.dart';
import 'package:PiliBro/common/widgets/dialog/report.dart';
import 'package:PiliBro/common/widgets/gesture/tap_gesture_recognizer.dart';
import 'package:PiliBro/common/widgets/image/network_img_layer.dart';
import 'package:PiliBro/common/widgets/image_grid/image_grid_view.dart';
import 'package:PiliBro/common/widgets/pendant_avatar.dart';
import 'package:PiliBro/common/widgets/text_ellipsis/text_ellipsis.dart';
import 'package:PiliBro/common/widgets/text_more/text_more.dart';
import 'package:PiliBro/common/widgets/translucent_row.dart';
import 'package:PiliBro/grpc/bilibili/main/community/reply/v1.pb.dart'
    show ReplyInfo, ReplyControl, Content, Url, ReplyControl_VoteOption, Emote;
import 'package:PiliBro/grpc/reply.dart';
import 'package:PiliBro/http/loading_state.dart';
import 'package:PiliBro/http/reply.dart';
import 'package:PiliBro/http/video.dart';
import 'package:PiliBro/models/common/image_type.dart';
import 'package:PiliBro/pages/dynamics/widgets/vote.dart';
import 'package:PiliBro/pages/member/widget/medal_widget.dart';
import 'package:PiliBro/pages/save_panel/view.dart';
import 'package:PiliBro/pages/video/controller.dart';
import 'package:PiliBro/pages/video/reply/widgets/zan_grpc.dart';
import 'package:PiliBro/utils/accounts.dart';
import 'package:PiliBro/utils/app_scheme.dart';
import 'package:PiliBro/utils/bili_utils.dart';
import 'package:PiliBro/utils/color_utils.dart';
import 'package:PiliBro/utils/danmaku_utils.dart';
import 'package:PiliBro/utils/date_utils.dart';
import 'package:PiliBro/utils/duration_utils.dart';
import 'package:PiliBro/utils/extension/context_ext.dart';
import 'package:PiliBro/utils/extension/iterable_ext.dart';
import 'package:PiliBro/utils/extension/num_ext.dart';
import 'package:PiliBro/utils/extension/selectable_region_ext.dart';
import 'package:PiliBro/utils/extension/theme_ext.dart';
import 'package:PiliBro/utils/feed_back.dart';
import 'package:PiliBro/utils/global_data.dart';
import 'package:PiliBro/utils/image_utils.dart';
import 'package:PiliBro/utils/page_utils.dart';
import 'package:PiliBro/utils/platform_utils.dart';
import 'package:PiliBro/utils/storage.dart';
import 'package:PiliBro/utils/storage_key.dart';
import 'package:PiliBro/utils/storage_pref.dart';
import 'package:PiliBro/utils/url_utils.dart';
import 'package:PiliBro/utils/utils.dart';
import 'package:cached_network_image_ce/cached_network_image.dart';
import 'package:collection/collection.dart' show IterableExtension;
import 'package:fixnum/fixnum.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';
import 'package:protobuf/protobuf.dart';

part 'package:PiliBro/common/widgets/context_menu/reply_menu_helper.dart';

class ReplyItemGrpc extends StatelessWidget {
  const ReplyItemGrpc({
    super.key,
    required this.replyItem,
    required this.replyLevel,
    this.replyReply,
    this.needDivider = true,
    this.onReply,
    this.onDelete,
    this.upMid,
    this.showDialogue,
    this.getTag,
    this.onViewImage,
    this.onCheckReply,
    this.onToggleTop,
    this.jumpToDialogue,
  });
  final ReplyInfo replyItem;
  final int replyLevel;
  final Function(ReplyInfo replyItem, int? rpid)? replyReply;
  final bool needDivider;
  final ValueChanged<ReplyInfo>? onReply;
  final Function(ReplyInfo replyItem, int? subIndex)? onDelete;
  final Int64? upMid;
  final VoidCallback? showDialogue;
  final Function? getTag;
  final VoidCallback? onViewImage;
  final ValueChanged<ReplyInfo>? onCheckReply;
  final ValueChanged<ReplyInfo>? onToggleTop;
  final VoidCallback? jumpToDialogue;

  static final _voteRegExp = RegExp(r"^\{vote:\d+?\}$");
  static final _timeRegExp = RegExp(r'^(?:\d+[:：])?\d+[:：]\d+$');
  static final _avBvRegExp = RegExp(r'^(av|bv)', caseSensitive: false);
  static final _cvidRegExp = RegExp(
    r'^cv(\d+)$|/read/cv(\d+)|note-app/view\?cvid=(\d+)',
    caseSensitive: false,
  );
  static final _baseMessageRegExp = RegExp(
    '${_timeRegExp.pattern}|${_voteRegExp.pattern}|${Constants.urlRegex.pattern}',
  );
  static final _messagePatternCache = Expando<RegExp>();
  static bool enableWordRe = Pref.enableWordRe;
  static int? replyLengthLimit = Pref.replyLengthLimit;

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.of(context);

    void showMore() => showModalBottomSheet(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxWidth: min(640, context.mediaQueryShortestSide),
      ),
      builder: (context) {
        return morePanel(
          context: context,
          item: replyItem,
          onDelete: () => onDelete?.call(replyItem, null),
          isSubReply: false,
        );
      },
    );

    Widget child = Padding(
      padding: const .fromLTRB(12, 14, 8, 5),
      child: _buildContent(context, colorScheme),
    );
    if (needDivider) {
      child = Column(
        mainAxisSize: .min,
        children: [
          child,
          Divider(
            indent: 55,
            endIndent: 15,
            height: 0.3,
            color: colorScheme.outline.withValues(alpha: 0.08),
          ),
        ],
      );
    }
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: () => replyReply?.call(replyItem, null),
        onLongPress: showMore,
        onSecondaryTap: PlatformUtils.isMobile ? null : showMore,
        child: child,
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ColorScheme colorScheme) {
    final member = replyItem.member;
    Widget header = GestureDetector(
      onTap: () {
        feedBack();
        Get.toNamed('/member?mid=${replyItem.mid}');
      },
      child: TranslucentRow(
        spacing: 12,
        extraWidth: 46,
        children: [
          PendantAvatar(
            member.face,
            size: 34,
            badgeSize: 14,
            vipStatus: member.vipStatus.toInt(),
            officialType: member.officialVerifyType.toInt(),
            pendantImage: member.hasGarbPendantImage()
                ? member.garbPendantImage
                : null,
          ),
          Flexible(
            child: Column(
              mainAxisSize: .min,
              crossAxisAlignment: .start,
              children: [
                Row(
                  spacing: 6,
                  mainAxisSize: .min,
                  children: [
                    Flexible(
                      child: Text(
                        member.name,
                        maxLines: 1,
                        overflow: .ellipsis,
                        style: TextStyle(
                          color: (member.vipStatus > 0 && member.vipType == 2)
                              ? colorScheme.vipColor
                              : colorScheme.outline,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    BiliUtils.levelPicture(
                      member.level.toInt(),
                      isSeniorMember: member.isSeniorMember == 1,
                      height: 11,
                    ),
                    if (replyItem.mid == upMid)
                      const PBadge(
                        text: 'UP',
                        size: .small,
                        isStack: false,
                        fontSize: 9,
                      )
                    else if (GlobalData().showMedal &&
                        member.hasFansMedalLevel())
                      MedalWidget(
                        medalName: member.fansMedalName,
                        level: member.fansMedalLevel.toInt(),
                        backgroundColor: DmUtils.decimalToColor(
                          member.fansMedalColor.toInt(),
                        ),
                        nameColor: DmUtils.decimalToColor(
                          member.fansMedalColorName.toInt(),
                        ),
                        padding: const .symmetric(horizontal: 6, vertical: 1.5),
                      ),
                  ],
                ),
                Row(
                  mainAxisSize: .min,
                  children: [
                    Text(
                      replyLevel == 0
                          ? DateFormatUtils.format(
                              replyItem.ctime.toInt(),
                              format: DateFormatUtils.longFormatDs,
                            )
                          : DateFormatUtils.dateFormat(replyItem.ctime.toInt()),
                      style: TextStyle(
                        fontSize: 11,
                        color: colorScheme.outline,
                      ),
                    ),
                    if (replyItem.replyControl.hasLocation())
                      Text(
                        ' • ${replyItem.replyControl.location}',
                        style: TextStyle(
                          fontSize: 11,
                          color: colorScheme.outline,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
    if (PendantAvatar.showDecorate) {
      final garb = replyItem.memberV2.garb;
      if (garb.hasCardImage()) {
        const double height = 38.0;
        return Stack(
          clipBehavior: .none,
          children: [
            Positioned(
              top: 0,
              right: 0,
              height: height,
              child: CachedNetworkImage(
                height: height,
                memCacheHeight: height.cacheSize(context),
                imageUrl: ImageUtils.safeThumbnailUrl(garb.cardImage),
                placeholder: (_, _) => const SizedBox.shrink(),
              ),
            ),
            if (garb.hasCardNumber())
              Positioned(
                top: 0,
                right: 0,
                height: height,
                child: Center(
                  child: Text(
                    '${garb.fanNumPrefix}\n${garb.cardNumber}',
                    style: TextStyle(
                      fontSize: 8,
                      fontFamily: Assets.digitalNum,
                      color: ColourUtils.parseColor(garb.cardFanColor),
                    ),
                  ),
                ),
              ),
            Padding(
              padding: const .only(right: 80),
              child: header,
            ),
          ],
        );
      }
    }
    return header;
  }

  Widget _buildVoteOption(
    ColorScheme colorScheme,
    ReplyControl_VoteOption voteOption,
  ) {
    return Text.rich(
      TextSpan(
        children: [
          switch (voteOption.labelKind) {
            .RED => TextSpan(
              text: '红方  ',
              style: TextStyle(color: colorScheme.vipColor),
            ),
            .BLUE => TextSpan(
              text: '蓝方  ',
              style: TextStyle(color: colorScheme.blue),
            ),
            _ => TextSpan(
              text: '投票  ',
              style: TextStyle(color: colorScheme.outline),
            ),
          },
          TextSpan(text: voteOption.desc),
        ],
      ),
      style: TextStyle(
        height: 1.75,
        fontSize: 12,
        color: colorScheme.onSurfaceVariant,
      ),
    );
  }

  Widget _buildContent(BuildContext context, ColorScheme colorScheme) {
    final replyControl = replyItem.replyControl;
    final padding = replyLevel == 0
        ? const EdgeInsets.only(left: 6, right: 6)
        : const EdgeInsets.only(left: 45, right: 6);
    return Column(
      mainAxisSize: .min,
      crossAxisAlignment: .start,
      children: [
        _buildHeader(context, colorScheme),
        const SizedBox(height: 10),
        if (replyControl.hasVoteOption())
          Padding(
            padding: padding,
            child: _buildVoteOption(colorScheme, replyControl.voteOption),
          ),
        Padding(
          padding: padding,
          child: TextMore.rich(
            primary: colorScheme.primary,
            style: const TextStyle(height: 1.75, fontSize: 14),
            maxLines: replyLevel == 1 ? replyLengthLimit : null,
            TextSpan(
              children: [
                if (replyControl.isUpTop) ...[
                  const WidgetSpan(
                    alignment: .middle,
                    child: PBadge(
                      text: 'TOP',
                      size: .small,
                      isStack: false,
                      type: .line_primary,
                      fontSize: 9,
                      textScaleFactor: 1,
                    ),
                  ),
                  const TextSpan(text: ' '),
                ],
                _buildMessage(
                  context,
                  colorScheme,
                  replyControl.showTranslation
                      ? replyItem.translatedContent
                      : replyItem.content,
                  replyControl,
                ),
              ],
            ),
          ),
        ),
        if (replyItem.content.pictures.isNotEmpty) ...[
          Padding(
            padding: padding,
            child: ImageGridView(
              picArr: replyItem.content.pictures
                  .map(
                    (item) => ImageModel(
                      width: item.imgWidth,
                      height: item.imgHeight,
                      url: item.imgSrc,
                    ),
                  )
                  .toList(),
              onViewImage: onViewImage,
            ),
          ),
          const SizedBox(height: 4),
        ],
        if (replyLevel != 0) ...[
          const SizedBox(height: 4),
          buttonAction(context, colorScheme, replyControl),
        ],
        if (replyLevel == 1 && replyItem.count > Int64.ZERO) ...[
          Padding(
            padding: const EdgeInsets.only(top: 5, bottom: 12),
            child: replyItemRow(context, colorScheme, replyItem.replies),
          ),
        ],
      ],
    );
  }

  Widget _buildTranslateBtn(
    BuildContext context,
    ColorScheme colorScheme,
    ReplyControl replyControl,
    TextStyle textStyle,
    ButtonStyle buttonStyle,
  ) {
    late bool isProcessing = false;
    final color = replyControl.showTranslation
        ? colorScheme.primary
        : colorScheme.outline.withValues(alpha: 0.8);
    return SizedBox(
      height: 32,
      child: TextButton(
        style: buttonStyle,
        onPressed: () async {
          if (replyControl.showTranslation) {
            replyControl.showTranslation = false;
            (context as Element).markNeedsBuild();
          } else {
            if (isProcessing) {
              return;
            }
            if (replyItem.hasTranslatedContent()) {
              replyControl.showTranslation = true;
              (context as Element).markNeedsBuild();
              return;
            }
            isProcessing = true;
            final res = await ReplyGrpc.translateReply(
              type: replyItem.type,
              oid: replyItem.oid,
              rpid: replyItem.id,
            );
            if (res case Success(:final response)) {
              final item = response.translatedReplies[replyItem.id];
              if (item != null && item.hasTranslatedContent()) {
                replyControl.showTranslation = true;
                replyItem.translatedContent = item.translatedContent;
                if (context.mounted) {
                  (context as Element).markNeedsBuild();
                }
              } else {
                SmartDialog.showToast('翻译结果为空');
              }
            } else if (res case Error(:final errMsg)) {
              SmartDialog.showToast('翻译失败: $errMsg');
            }
            isProcessing = false;
          }
        },
        child: Row(
          spacing: 3,
          mainAxisSize: .min,
          children: [
            Icon(Icons.translate, size: 16, color: color),
            Text(
              replyControl.showTranslation ? '原文' : '翻译',
              style: textStyle.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }

  Widget buttonAction(
    BuildContext context,
    ColorScheme colorScheme,
    ReplyControl replyControl,
  ) {
    final textStyle = TextStyle(
      height: 1,
      fontSize: 12,
      fontWeight: .normal,
      color: colorScheme.outline,
    );
    const buttonStyle = ButtonStyle(
      visualDensity: .compact,
      tapTargetSize: .shrinkWrap,
      padding: WidgetStatePropertyAll(.zero),
    );

    Widget? dialogBtn;
    if (replyLevel == 2 && needDivider && replyItem.id != replyItem.dialog) {
      dialogBtn = SizedBox(
        height: 32,
        child: TextButton(
          onPressed: showDialogue,
          style: buttonStyle,
          child: Text('查看对话', style: textStyle),
        ),
      );
    } else if (replyLevel == 3 && replyItem.parent != replyItem.root) {
      dialogBtn = SizedBox(
        height: 32,
        child: TextButton(
          onPressed: jumpToDialogue,
          style: buttonStyle,
          child: Text('跳转回复', style: textStyle),
        ),
      );
    }
    return Row(
      children: [
        const SizedBox(width: 36),
        SizedBox(
          height: 32,
          child: TextButton(
            style: buttonStyle,
            onPressed: () {
              feedBack();
              onReply?.call(replyItem);
            },
            child: Row(
              spacing: 3,
              mainAxisSize: .min,
              children: [
                Icon(
                  Icons.reply,
                  size: 18,
                  color: colorScheme.outline.withValues(alpha: 0.8),
                ),
                Text('回复', style: textStyle),
              ],
            ),
          ),
        ),
        const SizedBox(width: 2),
        if (replyControl.translationSwitch ==
            .TRANSLATION_SWITCH_SHOW_TRANSLATION) ...[
          _buildTranslateBtn(
            context,
            colorScheme,
            replyControl,
            textStyle,
            buttonStyle,
          ),
          const SizedBox(width: 2),
        ] else if (replyControl.cardLabels.isNotEmpty) ...[
          Text(
            dialogBtn != null
                ? replyControl.cardLabels.first.textContent
                : replyControl.cardLabels.map((e) => e.textContent).join('  '),
            style: textStyle.copyWith(color: colorScheme.secondary),
          ),
          const SizedBox(width: 2),
        ],
        ?dialogBtn,
        const Spacer(),
        ZanButtonGrpc(replyItem: replyItem),
        const SizedBox(width: 5),
      ],
    );
  }

  Widget replyItemRow(
    BuildContext context,
    ColorScheme colorScheme,
    List<ReplyInfo> replies,
  ) {
    final extraRow = replies.length < replyItem.count.toInt();
    final length = replies.length + (extraRow ? 1 : 0);
    return Padding(
      padding: const .only(left: 42, right: 4),
      child: Material(
        animationDuration: .zero,
        color: colorScheme.onInverseSurface,
        borderRadius: const .all(.circular(6)),
        child: Column(
          crossAxisAlignment: .stretch,
          children: [
            if (replies.isNotEmpty)
              ...replies.mapIndexed((index, childReply) {
                final EdgeInsets padding;
                BorderRadius? borderRadius;
                if (length == 1) {
                  padding = const .fromLTRB(8, 5, 8, 5);
                  borderRadius = const .all(.circular(6));
                } else {
                  if (index == 0) {
                    padding = const .fromLTRB(8, 8, 8, 4);
                    borderRadius = const .vertical(top: .circular(6));
                  } else if (index == length - 1) {
                    padding = const .fromLTRB(8, 4, 8, 8);
                    borderRadius = const .vertical(bottom: .circular(6));
                  } else {
                    padding = const .fromLTRB(8, 4, 8, 4);
                  }
                }
                void showMore() => showModalBottomSheet(
                  context: context,
                  useSafeArea: true,
                  isScrollControlled: true,
                  constraints: BoxConstraints(
                    maxWidth: min(640, context.mediaQueryShortestSide),
                  ),
                  builder: (context) {
                    return morePanel(
                      context: context,
                      item: childReply,
                      onDelete: () => onDelete?.call(replyItem, index),
                      isSubReply: true,
                    );
                  },
                );
                return InkWell(
                  borderRadius: borderRadius,
                  onTap: () =>
                      replyReply?.call(replyItem, childReply.id.toInt()),
                  onLongPress: showMore,
                  onSecondaryTap: PlatformUtils.isMobile ? null : showMore,
                  child: Padding(
                    padding: padding,
                    child: TextEllipsis.rich(
                      style: TextStyle(
                        height: 1.6,
                        fontSize: 14,
                        color: colorScheme.onSurface.withValues(alpha: 0.85),
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                      TextSpan(
                        children: [
                          TextSpan(
                            text: childReply.member.name,
                            style: TextStyle(color: colorScheme.primary),
                            recognizer: NoDeadlineTapGestureRecognizer()
                              ..onTap = () {
                                feedBack();
                                Get.toNamed(
                                  '/member?mid=${childReply.member.mid}',
                                );
                              },
                          ),
                          if (childReply.mid == upMid) ...[
                            const TextSpan(text: ' '),
                            const WidgetSpan(
                              alignment: .middle,
                              child: PBadge(
                                text: 'UP',
                                size: .small,
                                isStack: false,
                                fontSize: 9,
                                textScaleFactor: 1,
                              ),
                            ),
                            const TextSpan(text: ' '),
                          ],
                          TextSpan(
                            text: childReply.root == childReply.parent
                                ? ': '
                                : childReply.mid == upMid
                                ? ''
                                : ' ',
                          ),
                          _buildMessage(
                            context,
                            colorScheme,
                            childReply.content,
                            childReply.replyControl,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            if (extraRow)
              InkWell(
                onTap: () => replyReply?.call(replyItem, null),
                borderRadius: length == 1
                    ? const .all(.circular(6))
                    : const .vertical(bottom: .circular(6)),
                child: Padding(
                  padding: length == 1
                      ? const .fromLTRB(8, 6, 8, 6)
                      : const .fromLTRB(8, 5, 8, 8),
                  child: Text.rich(
                    TextSpan(
                      style: const TextStyle(fontSize: 12),
                      children: [
                        if (replyItem.replyControl.upReply)
                          TextSpan(
                            text: 'UP主等人 ',
                            style: TextStyle(
                              color: colorScheme.onSurface.withValues(
                                alpha: 0.85,
                              ),
                            ),
                          ),
                        TextSpan(
                          text: '共${replyItem.count}条回复',
                          style: TextStyle(
                            color: colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  InlineSpan _buildMessage(
    BuildContext context,
    ColorScheme colorScheme,
    Content content,
    ReplyControl replyControl,
  ) {
    final message = content.message;
    final noMappedTokens =
        content.emotes.isEmpty &&
        content.topics.isEmpty &&
        content.atNameToMid.isEmpty &&
        content.urls.isEmpty;
    if (noMappedTokens &&
        !message.contains(':') &&
        !message.contains('：') &&
        !message.contains('{') &&
        !message.contains('http')) {
      return TextSpan(text: message);
    }

    final List<InlineSpan> spanChildren = <InlineSpan>[];
    bool hasNote = false;

    final pattern = noMappedTokens
        ? _baseMessageRegExp
        : _messagePatternCache[content] ??= (() {
            final buffer = StringBuffer();
            var first = true;
            void addToken(String token) {
              if (first) {
                first = false;
              } else {
                buffer.write('|');
              }
              buffer.write(RegExp.escape(token));
            }

            for (final token in content.emotes.keys) addToken(token);
            for (final token in content.topics.keys) addToken('#$token#');
            for (final token in content.atNameToMid.keys) addToken('@$token');
            for (final token in content.urls.keys) addToken(token);
            if (!first) buffer.write('|');
            buffer.write(_baseMessageRegExp.pattern);
            return RegExp(buffer.toString());
          })();

    late final primaryStyle = TextStyle(color: colorScheme.primary);
    late final matchedUrls = <String>{};

    void addPlainTextSpan(str) {
      spanChildren.add(TextSpan(text: str));
    }

    void addUrl(String matchStr, Url url, {bool addPlainText = false}) {
      if (url.extra.isWordSearch && !enableWordRe) {
        if (addPlainText) {
          addPlainTextSpan(matchStr);
        }
        return;
      }
      final isCv = url.clickReport.startsWith('{"cvid');
      if (isCv) {
        hasNote = true;
      }
      final children = [
        if (!isCv && url.hasPrefixIcon())
          WidgetSpan(
            child: CachedNetworkImage(
              height: 19,
              memCacheHeight: 19.cacheSize(context),
              color: colorScheme.primary,
              imageUrl: ImageUtils.thumbnailUrl(url.prefixIcon),
              placeholder: (_, _) => const SizedBox.shrink(),
            ),
          ),
        TextSpan(
          text: isCv ? '[笔记] ' : url.title,
          style: primaryStyle,
          recognizer: NoDeadlineTapGestureRecognizer()
            ..onTap = () {
              if (url.appUrlSchema.isEmpty) {
                if (_avBvRegExp.hasMatch(matchStr)) {
                  UrlUtils.matchUrlPush(matchStr, '');
                } else {
                  final match = _cvidRegExp.firstMatch(matchStr);
                  final cvid =
                      match?.group(1) ?? match?.group(2) ?? match?.group(3);
                  if (cvid != null) {
                    Get.toNamed(
                      '/articlePage',
                      parameters: {
                        'id': cvid,
                        'type': 'read',
                      },
                    );
                    return;
                  }
                  PageUtils.handleWebview(matchStr);
                }
              } else {
                if (url.extra.isWordSearch) {
                  Get.toNamed(
                    '/searchResult',
                    parameters: {'keyword': url.title},
                  );
                } else {
                  PageUtils.handleWebview(matchStr);
                }
              }
            },
        ),
      ];
      if (isCv) {
        spanChildren.insertAll(0, children);
      } else {
        spanChildren.addAll(children);
      }
    }

    // 分割文本并处理每个部分
    message.splitMapJoin(
      pattern,
      onMatch: (Match match) {
        String matchStr = match[0]!;
        final firstCode = matchStr.codeUnitAt(0);
        late final name = matchStr.substring(1);
        late final topic = matchStr.substring(1, matchStr.length - 1);
        late final atMid = content.atNameToMid[name];
        final emote = content.emotes[matchStr];
        if (emote != null) {
          // 处理表情
          final size = emote.size.toInt() * 20.0;
          spanChildren.add(
            WidgetSpan(
              child: NetworkImgLayer(
                src: emote.hasWebpUrl()
                    ? emote.webpUrl
                    : emote.hasGifUrl()
                    ? emote.gifUrl
                    : emote.url,
                type: ImageType.emote,
                width: size,
                height: size,
              ),
            ),
          );
        } else if (firstCode == 0x40 && atMid != null) {
          // 处理@用户
          spanChildren.add(
            TextSpan(
              text: matchStr,
              style: TextStyle(color: colorScheme.primary),
              recognizer: NoDeadlineTapGestureRecognizer()
                ..onTap = () => Get.toNamed('/member?mid=$atMid'),
            ),
          );
        } else if (firstCode == 0x7B && _voteRegExp.hasMatch(matchStr)) {
          spanChildren.add(
            TextSpan(
              text: '投票: ${content.vote.title}',
              style: TextStyle(color: colorScheme.primary),
              recognizer: NoDeadlineTapGestureRecognizer()
                ..onTap = () =>
                    showVoteDialog(context, content.vote.id.toInt()),
            ),
          );
        } else if (firstCode >= 0x30 &&
            firstCode <= 0x39 &&
            _timeRegExp.hasMatch(matchStr)) {
          matchStr = matchStr.replaceAll('：', ':');
          bool isValid = false;
          try {
            final ctr = Get.find<VideoDetailController>(
              tag: getTag?.call() ?? Get.arguments['heroTag'],
            );
            isValid =
                DurationUtils.parseDuration(matchStr) * 1000 <=
                ctr.data.timeLength!;
          } catch (e) {
            if (kDebugMode) debugPrint('failed to validate: $e');
          }
          spanChildren.add(
            TextSpan(
              text: isValid ? ' $matchStr ' : matchStr,
              style: isValid ? TextStyle(color: colorScheme.primary) : null,
              recognizer: isValid
                  ? (NoDeadlineTapGestureRecognizer()
                      ..onTap = () {
                        // 跳转到指定位置
                        try {
                          SmartDialog.showToast('跳转至：$matchStr');
                          Get.find<VideoDetailController>(
                            tag: Get.arguments['heroTag'],
                          ).plPlayerController.seekTo(
                            Duration(
                              seconds: DurationUtils.parseDuration(matchStr),
                            ),
                            isSeek: false,
                          );
                        } catch (e) {
                          SmartDialog.showToast('跳转失败: $e');
                        }
                      })
                  : null,
            ),
          );
        } else {
          final url = content.urls[matchStr];
          if (url != null && !matchedUrls.contains(matchStr)) {
            addUrl(matchStr, url, addPlainText: true);
            // 只显示一次
            matchedUrls.add(matchStr);
          } else if (matchStr.length > 1 && content.topics[topic] != null) {
            spanChildren.add(
              TextSpan(
                text: matchStr,
                style: TextStyle(color: colorScheme.primary),
                recognizer: NoDeadlineTapGestureRecognizer()
                  ..onTap = () {
                    Get.toNamed(
                      '/searchResult',
                      parameters: {'keyword': topic},
                    );
                  },
              ),
            );
          } else if (Constants.urlRegex.hasMatch(matchStr)) {
            spanChildren.add(
              TextSpan(
                text: matchStr,
                style: TextStyle(color: colorScheme.primary),
                recognizer: NoDeadlineTapGestureRecognizer()
                  ..onTap = () => PageUtils.handleWebview(matchStr),
              ),
            );
          } else {
            addPlainTextSpan(matchStr);
          }
        }
        return '';
      },
      onNonMatch: (String nonMatchStr) {
        addPlainTextSpan(nonMatchStr);
        return nonMatchStr;
      },
    );

    // if (urlKeys.isNotEmpty) {
    //   List<String> unmatchedItems = urlKeys
    //       .where((url) => !matchedUrls.contains(url))
    //       .toList();
    //   if (unmatchedItems.isNotEmpty) {
    //     for (final patternStr in unmatchedItems) {
    //       addUrl(patternStr, content.urls[patternStr]!);
    //     }
    //   }
    // }

    if (!hasNote && replyControl.isNote && replyControl.isNoteV2) {
      final Color color;
      NoDeadlineTapGestureRecognizer? recognizer;

      final hasClickUrl = content.richText.note.hasClickUrl();
      if (hasClickUrl || content.richText.opus.hasOpusId()) {
        color = colorScheme.primary;
        recognizer = NoDeadlineTapGestureRecognizer()
          ..onTap = () => hasClickUrl
              ? PiliScheme.routePushFromUrl(content.richText.note.clickUrl)
              : Get.toNamed(
                  '/articlePage',
                  parameters: {
                    'id': content.richText.opus.opusId.toString(),
                    'type': 'opus',
                  },
                );
      } else {
        color = colorScheme.secondary;
      }
      spanChildren.insert(
        0,
        TextSpan(
          text: '[笔记] ',
          style: TextStyle(color: color),
          recognizer: recognizer,
        ),
      );
    }

    return TextSpan(children: spanChildren);
  }

  Widget morePanel({
    required BuildContext context,
    required ReplyInfo item,
    required VoidCallback onDelete,
    required bool isSubReply,
  }) {
    late String message = item.content.message;
    final ownerMid = Int64(Accounts.main.mid);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final errorColor = colorScheme.error;
    final style = theme.textTheme.titleSmall!;

    return Padding(
      padding: .only(
        bottom: MediaQuery.viewPaddingOf(context).bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: Get.back,
            borderRadius: Style.bottomSheetRadius,
            child: SizedBox(
              height: 35,
              child: Center(
                child: Container(
                  width: 32,
                  height: 3,
                  decoration: BoxDecoration(
                    color: colorScheme.outline,
                    borderRadius: const BorderRadius.all(Radius.circular(3)),
                  ),
                ),
              ),
            ),
          ),
          if (kDebugMode && GStorage.reply != null) ...[
            ListTile(
              onTap: () {
                Get.back();
                GStorage.reply!.put(
                  item.id.toString(),
                  (item.deepCopy()
                        ..unknownFields.clear()
                        ..replies.clear()
                        ..clearTrackInfo())
                      .writeToBuffer(),
                );
              },
              title: Text(
                'save to local',
                style: style.copyWith(color: colorScheme.primary),
              ),
            ),
            ListTile(
              onTap: () {
                Get.back();
                onDelete();
                GStorage.reply!.delete(item.id.toString());
              },
              title: Text(
                'remove from local',
                style: style.copyWith(color: colorScheme.primary),
              ),
            ),
            ListTile(
              onTap: () {
                Get.back();
                final oid = item.oid.toInt();
                final data =
                    (item.deepCopy()
                          ..unknownFields.clear()
                          ..replies.clear()
                          ..clearTrackInfo())
                        .writeToBuffer();
                GStorage.reply!.putAll({
                  for (var i = oid; i < oid + 1000; i++) i.toString(): data,
                });
              },
              title: Text(
                'save to local (x1000)',
                style: style.copyWith(color: colorScheme.primary),
              ),
            ),
          ],
          if (ownerMid == upMid || ownerMid == item.member.mid)
            ListTile(
              onTap: () async {
                Get.back();
                bool? isDelete = await showDialog<bool>(
                  context: context,
                  builder: (context) {
                    final colorScheme = ColorScheme.of(context);
                    return AlertDialog(
                      title: const Text('删除评论'),
                      content: Text.rich(
                        TextSpan(
                          children: [
                            const TextSpan(text: '确定删除这条评论吗？\n\n'),
                            if (ownerMid != item.member.mid.toInt()) ...[
                              TextSpan(
                                text: '@${item.member.name}',
                                style: TextStyle(
                                  color: colorScheme.primary,
                                ),
                              ),
                              const TextSpan(text: ':\n'),
                            ],
                            TextSpan(text: message),
                          ],
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Get.back(result: false),
                          child: Text(
                            '取消',
                            style: TextStyle(
                              color: colorScheme.outline,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () => Get.back(result: true),
                          child: const Text('确定'),
                        ),
                      ],
                    );
                  },
                );
                if (isDelete == null || !isDelete) {
                  return;
                }
                SmartDialog.showLoading(msg: '删除中...');
                final res = await VideoHttp.replyDel(
                  type: item.type.toInt(),
                  oid: item.oid.toInt(),
                  rpid: item.id.toInt(),
                );
                SmartDialog.dismiss();
                if (res.isSuccess) {
                  SmartDialog.showToast('删除成功');
                  onDelete();
                } else {
                  SmartDialog.showToast('删除失败, $res');
                }
              },
              minLeadingWidth: 0,
              leading: Icon(Icons.delete_outlined, color: errorColor, size: 19),
              title: Text('删除', style: style.copyWith(color: errorColor)),
            ),
          if (ownerMid != Int64.ZERO)
            ListTile(
              onTap: () {
                Get.back();
                autoWrapReportDialog(
                  context,
                  ReportOptions.commentReport,
                  (reasonType, reasonDesc, banUid) async {
                    final res = await ReplyHttp.report(
                      rpid: item.id,
                      oid: item.oid,
                      reasonType: reasonType,
                      reasonDesc: reasonDesc,
                      banUid: banUid,
                    );
                    if (res.isSuccess) {
                      onDelete();
                    }
                    return res;
                  },
                );
              },
              minLeadingWidth: 0,
              leading: Icon(Icons.error_outline, color: errorColor, size: 19),
              title: Text('举报', style: style.copyWith(color: errorColor)),
            ),
          if (replyLevel == 1 && !isSubReply && ownerMid == upMid)
            ListTile(
              onTap: () {
                Get.back();
                onToggleTop?.call(item);
              },
              minLeadingWidth: 0,
              leading: const Icon(Icons.vertical_align_top, size: 19),
              title: Text(
                '${replyItem.replyControl.isUpTop ? '取消' : ''}置顶',
                style: style,
              ),
            ),
          ListTile(
            onTap: () {
              Get.back();
              Utils.copyText(message);
            },
            minLeadingWidth: 0,
            leading: const Icon(Icons.copy_all_outlined, size: 19),
            title: Text('复制全部', style: style),
          ),
          ListTile(
            onTap: () {
              Get.back();
              showReplyCopyDialog(context, message, item.content.emotes);
            },
            minLeadingWidth: 0,
            leading: const Icon(Icons.copy_outlined, size: 19),
            title: Text('自由复制', style: style),
          ),
          ListTile(
            onTap: () {
              Get.back();
              SavePanel.toSavePanel(upMid: upMid, item: item);
            },
            minLeadingWidth: 0,
            leading: const Icon(Icons.save_alt, size: 19),
            title: Text('保存评论', style: style),
          ),
          if (kDebugMode || item.mid == ownerMid)
            ListTile(
              onTap: () {
                Get.back();
                onCheckReply?.call(item);
              },
              minLeadingWidth: 0,
              leading: const Icon(CustomIcons.shield_reply, size: 19),
              title: Text('检查评论', style: style),
            ),
        ],
      ),
    );
  }
}
