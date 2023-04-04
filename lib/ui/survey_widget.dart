import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_survey_js/model/survey.dart' as s;
import 'package:flutter_survey_js/survey.dart';
import 'package:logging/logging.dart';
import 'package:reactive_forms/reactive_forms.dart';

import 'elements_state.dart';
import 'form_control.dart';

final defaultBuilder = (BuildContext context) {
  return SurveyLayout();
};

typedef SurveyBuilder = Widget Function(BuildContext context);

class SurveyWidget extends StatefulWidget {
  final s.Survey survey;
  final Map<String, Object?>? answer;
  final FutureOr<void> Function(dynamic data)? onSubmit;
  final ValueSetter<Map<String, Object?>?>? onChange;
  final bool showQuestionsInOnePage;
  final SurveyController? controller;
  final SurveyBuilder? builder;
  final Color focusColor;
  final ButtonStyle? focusableButtonStyle;
  final Decoration? elementDecoration;
  final EdgeInsetsGeometry? elementPadding;


  const SurveyWidget({
    Key? key,
    required this.survey,
    this.answer,
    this.onSubmit,
    this.onChange,
    this.controller,
    this.builder,
    this.showQuestionsInOnePage = false,
    this.focusColor = Colors.black,
    this.focusableButtonStyle,
    this.elementDecoration,
    this.elementPadding,
  }) : super(key: key);
  @override
  State<StatefulWidget> createState() => SurveyWidgetState();
}

class SurveyWidgetState extends State<SurveyWidget> {
  final Logger logger = Logger('SurveyWidgetState');
  late FormGroup formGroup;
  late Map<s.ElementBase, Object> _controlsMap;

  late int pageCount;

  StreamSubscription<Map<String, Object?>?>? _listener;

  int _currentPage = 0;

  // TODO calculate initial page
  int initialPage = 0;

  int get currentPage => _currentPage;

  @override
  void initState() {
    super.initState();
    widget.controller?._bind(this);
    rebuildForm();
  }

  static SurveyWidgetState of(BuildContext context) {
    return context.findAncestorStateOfType<SurveyWidgetState>()!;
  }

  void toPage(int newPage) {
    final p = max(0, min(pageCount - 1, newPage));
    setState(() {
      _currentPage = p;
    });
  }

  @override
  Widget build(BuildContext context) {
    //TODO recalculate page count and visible
    //TODO calculate status
    Map<s.ElementBase, ElementStatus> status = {};
    int index = 0;
    for (final kv in _controlsMap.entries) {
      var visible = true;
      status[kv.key] = ElementStatus(indexAll: index);
      if (visible) {
        index++;
      }
    }
    final elementsState = ElementsState(status);

    return Theme(
      data: Theme.of(context).copyWith(
        focusColor: widget.focusColor,
        textButtonTheme:
            TextButtonThemeData(style: widget.focusableButtonStyle),
        inputDecorationTheme: InputDecorationTheme(),
      ),
      child: ReactiveForm(
        formGroup: this.formGroup,
        child: StreamBuilder(
          stream: this.formGroup.valueChanges,
          builder: (BuildContext context,
              AsyncSnapshot<Map<String, Object?>?> snapshot) {
            return SurveyProvider(
              survey: widget.survey,
              formGroup: formGroup,
              elementsState: elementsState,
              currentPage: currentPage,
              initialPage: initialPage,
              showQuestionsInOnePage: widget.showQuestionsInOnePage,
              focusColor: widget.focusColor,
              elementDecoration: widget.elementDecoration,
              elementPadding: widget.elementPadding,
              child: Builder(
                  builder: (context) =>
                      (widget.builder ?? defaultBuilder)(context)),
            );
          },
        ),
      ),
    );
  }

  void rebuildForm() {
    logger.info("Rebuild form");
    _listener?.cancel();
    //clear
    _controlsMap = {};
    _currentPage = 0;

    this.formGroup = elementsToFormGroup(widget.survey.getElements(),
        controlsMap: _controlsMap);

    formGroup.patchValue(widget.answer, updateParent: true);

    _listener = this.formGroup.valueChanges.listen((event) {
      logger.fine('Value changed $event');
      widget.onChange?.call(event);
    });

    pageCount = widget.survey.getPageCount();
    if (widget.showQuestionsInOnePage) {
      pageCount = 1;
    }
  }

  void submit() {
    if (formGroup.valid) {
      widget.onSubmit?.call(formGroup.value);
    } else {
      formGroup.markAllAsTouched();
    }
  }

  void dispose() {
    _listener?.cancel();
    widget.controller?._detach();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant SurveyWidget oldWidget) {
    if (oldWidget.survey != widget.survey) {
      rebuildForm();
    }
    super.didUpdateWidget(oldWidget);
  }

  // nextPageOrSubmit return true if submit or return false for next page
  bool nextPageOrSubmit() {
    final bool finished = _currentPage >= pageCount - 1;
    if (!finished) {
      toPage(_currentPage + 1);
    } else {
      submit();
    }
    return finished;
  }
}

class SurveyProvider extends InheritedWidget {
  final Widget child;
  final s.Survey survey;
  final FormGroup formGroup;
  final ElementsState elementsState;
  final int currentPage;
  final int initialPage;
  final bool showQuestionsInOnePage;
  final Color focusColor;
  final Decoration? elementDecoration;
  final EdgeInsetsGeometry? elementPadding;


  SurveyProvider({
    required this.elementsState,
    required this.child,
    required this.survey,
    required this.formGroup,
    required this.currentPage,
    required this.initialPage,
    required this.focusColor,
    this.elementDecoration,
    this.elementPadding,
    this.showQuestionsInOnePage = false,
  }) : super(child: child);

  static SurveyProvider of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<SurveyProvider>()!;
  }

  @override
  bool updateShouldNotify(covariant SurveyProvider oldWidget) => true;
}

extension SurveyFormExtension on s.Survey {
  List<s.ElementBase> getElements() {
    return questions ??
        pages!.fold<List<s.ElementBase>>(
            [],
            (previousValue, element) =>
                previousValue..addAll(element.elements ?? []));
  }
}

// SurveyController use to control SurveyWidget behavior
class SurveyController {
  SurveyWidgetState? _widgetState;

  int get currentPage {
    assert(_widgetState != null, "SurveyWidget not initialized");
    return _widgetState!._currentPage;
  }

  int get pageCount {
    assert(_widgetState != null, "SurveyWidget not initialized");
    return _widgetState!.pageCount;
  }

  void _bind(SurveyWidgetState state) {
    assert(_widgetState == null,
        "Don't use one SurveyController to multiple SurveyWidget");
    _widgetState = state;
  }

  void _detach() {
    _widgetState = null;
  }

  void submit() {
    assert(_widgetState != null, "SurveyWidget not initialized");
    _widgetState?.submit();
  }

  // nextPageOrSubmit return true if submit or return false for next page
  bool nextPageOrSubmit() {
    assert(_widgetState != null, "SurveyWidget not initialized");
    return _widgetState!.nextPageOrSubmit();
  }

  void prePage() {
    assert(_widgetState != null, "SurveyWidget not initialized");
    toPage(currentPage - 1);
  }

  void toPage(int newPage) {
    assert(_widgetState != null, "SurveyWidget not initialized");
    _widgetState!.toPage(newPage);
  }
}

extension SurveyExtension on s.Survey {
  int getPageCount() {
    return this.questions == null ? (this.pages ?? []).length : 1;
  }
}
