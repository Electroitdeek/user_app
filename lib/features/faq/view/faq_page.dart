import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_edge_insets.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/screen_dimensions.dart';
import '../../../data/models/faq_model.dart';
import '../../../di/locator.dart';
import '../../../shared/widgets/common/app_bar_custom.dart';
import '../../../shared/widgets/common/app_search_field.dart';
import '../../../shared/widgets/common/custom_error_view.dart';
import '../bloc/faq_bloc.dart';
import '../bloc/faq_event.dart';
import '../bloc/faq_state.dart';

class FaqPage extends StatefulWidget {
  const FaqPage({super.key});

  @override
  State<FaqPage> createState() => _FaqPageState();
}

class _FaqPageState extends State<FaqPage> {
  late FaqBloc _faqBloc;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _faqBloc = locator<FaqBloc>()..add(FetchFaqsEvent());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => _faqBloc,
      child: Scaffold(
        backgroundColor: kScaffoldColor,
        appBar: const CustomAppBar(title: 'Help Center'),
        body: BlocBuilder<FaqBloc, FaqState>(
          builder: (context, state) {
            if (state is FaqLoading) {
              return const Center(child: CircularProgressIndicator(color: kPrimaryColor));
            } else if (state is FaqError) {
              return CustomErrorView(message: state.message, onRetry: () => _faqBloc.add(FetchFaqsEvent()));
            } else if (state is FaqLoaded) {
              var filteredFaqs = state.faqs;
              if (_searchQuery.isNotEmpty) {
                filteredFaqs = filteredFaqs.where((faq) {
                  return faq.question.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                      faq.answer.toLowerCase().contains(_searchQuery.toLowerCase());
                }).toList();
              }

              return SafeArea(
                top: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    Padding(
                      padding: AppPadding.screenHorizontal,
                      child: AppSearchField(
                        controller: _searchController,
                        hintText: 'Search your questions...',
                        onChanged: (value) => setState(() => _searchQuery = value),
                      ),
                    ),
                    AppSpacing.sVertical,
                    Expanded(
                      child: filteredFaqs.isEmpty
                          ? _buildEmptyState()
                          : ListView.separated(
                              padding: AppPadding.only(left: 20, top: 16, right: 20, bottom: 30),
                              itemCount: filteredFaqs.length,
                              separatorBuilder: (context, index) => AppSpacing.mVertical,
                              itemBuilder: (context, index) => _FaqTile(faq: filteredFaqs[index]),
                            ),
                    ),
                  ],
                ),
              );
            }
            return const SizedBox();
          },
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: AppPadding.only(left: 20, top: 8, right: 20, bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('How can we help you?', style: kHeadingSmall(color: kTextPrimaryColor)),
          AppSpacing.xsVertical,
          Text('Find quick answers to common questions', style: kTextNormal(color: kTextSecondaryColor)),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(20.r),
            decoration: BoxDecoration(color: kPrimaryColor.withValues(alpha: 0.06), shape: BoxShape.circle),
            child: Icon(Icons.search_off_rounded, size: 48.sp, color: kPrimaryColor),
          ),
          AppSpacing.lVertical,
          Text('No results found', style: kTextBold1(color: kTextPrimaryColor)),
          AppSpacing.xsVertical,
          Text('Try a different keyword', style: kTextNormal(color: kTextSecondaryColor)),
        ],
      ),
    );
  }
}

class _FaqTile extends StatefulWidget {
  final FaqData faq;

  const _FaqTile({required this.faq});

  @override
  State<_FaqTile> createState() => _FaqTileState();
}

class _FaqTileState extends State<_FaqTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: kWhiteColor,
        borderRadius: AppRadius.l,
        border: Border.all(
          color: _expanded ? kPrimaryColor.withValues(alpha: 0.4) : kBorderColor.withValues(alpha: 0.4),
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          onExpansionChanged: (v) => setState(() => _expanded = v),
          tilePadding: AppPadding.symmetric(h: 16, v: 4),
          title: Text(
            widget.faq.question,
            style: kTextBold(color: kTextPrimaryColor).copyWith(fontSize: 14.sp, height: 1.35),
          ),
          trailing: AnimatedRotation(
            turns: _expanded ? 0.5 : 0,
            duration: const Duration(milliseconds: 200),
            child: Container(
              padding: EdgeInsets.all(4.r),
              decoration: BoxDecoration(
                color: _expanded ? kPrimaryColor : kPrimaryColor.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 18.sp,
                color: _expanded ? kWhiteColor : kPrimaryColor,
              ),
            ),
          ),
          childrenPadding: AppPadding.only(left: 16, right: 16, bottom: 16),
          expandedAlignment: Alignment.topLeft,
          children: [
            Divider(height: 1, color: kBorderColor.withValues(alpha: 0.4)),
            AppSpacing.sVertical,
            Text(widget.faq.answer, style: kTextNormal(color: kTextSecondaryColor).copyWith(height: 1.55)),
          ],
        ),
      ),
    );
  }
}
