import 'package:flutter/material.dart';

import 'comment_models.dart';

const List<Color> threadColors = [
  Color(0xFF5B9BD5), // Blue
  Color(0xFF70BF73), // Green
  Color(0xFFE8944A), // Orange
  Color(0xFFB07CC6), // Purple
];

class CommentNode {
  CommentNode({required this.comment}) : children = [];
  final Comment comment;
  final List<CommentNode> children;
}

List<CommentNode> buildCommentTree(List<Comment> flat) {
  final map = <String, CommentNode>{};
  for (final c in flat) {
    map[c.id] = CommentNode(comment: c);
  }
  final roots = <CommentNode>[];
  for (final c in flat) {
    final node = map[c.id]!;
    if (c.parentId == null || c.parentId!.isEmpty || !map.containsKey(c.parentId)) {
      roots.add(node);
    } else {
      map[c.parentId]!.children.add(node);
    }
  }
  void sortByDate(CommentNode n) {
    n.children.sort((a, b) => a.comment.createdAt.compareTo(b.comment.createdAt));
    for (final ch in n.children) {
      sortByDate(ch);
    }
  }
  roots.sort((a, b) => a.comment.createdAt.compareTo(b.comment.createdAt));
  for (final r in roots) {
    sortByDate(r);
  }
  return roots;
}
