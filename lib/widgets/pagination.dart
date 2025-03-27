import 'package:flutter/material.dart';

class PaginationWidget extends StatefulWidget {
  final int currentPage;
  final int totalPages;
  final int currentPageItemCount;
  final int totalDatos;
  final bool isDarkMode;
  final Function(int) onPageChanged;

  const PaginationWidget({
    required this.currentPage,
    required this.totalPages,
    required this.currentPageItemCount,
    required this.totalDatos,
    required this.isDarkMode,
    required this.onPageChanged,
  });

  @override
  _PaginationWidgetState createState() => _PaginationWidgetState();
}

class _PaginationWidgetState extends State<PaginationWidget> {
  int? _hoveredPage;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: widget.isDarkMode ? Colors.grey[850] : Colors.white,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
        border: Border(
          top: BorderSide(
            color: widget.isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Mostrando ${widget.currentPageItemCount} de ${widget.totalDatos}',
            style: TextStyle(
              color: widget.isDarkMode ? Colors.grey[400] : Colors.grey[600],
              fontSize: 12,
            ),
          ),
          Row(
            children: [
              IconButton(
                icon: Icon(
                  Icons.chevron_left,
                  color: widget.currentPage > 1
                      ? (widget.isDarkMode ? Colors.white : Colors.black87)
                      : Colors.grey[400],
                  size: 20,
                ),
                onPressed: widget.currentPage > 1
                    ? () => widget.onPageChanged(widget.currentPage - 1)
                    : null,
              ),
              Row(children: _buildPageNumbers()),
              IconButton(
                icon: Icon(
                  Icons.chevron_right,
                  color: widget.currentPage < widget.totalPages
                      ? (widget.isDarkMode ? Colors.white : Colors.black87)
                      : Colors.grey[400],
                  size: 20,
                ),
                onPressed: widget.currentPage < widget.totalPages
                    ? () => widget.onPageChanged(widget.currentPage + 1)
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _buildPageNumbers() {
    List<Widget> pageNumbers = [];
    pageNumbers.add(_pageNumberButton(1, widget.currentPage == 1));

    if (widget.currentPage > 3) {
      pageNumbers.add(_ellipsisButton());
    }

    for (int i = max(2, widget.currentPage - 1);
        i <= min(widget.totalPages - 1, widget.currentPage + 1);
        i++) {
      if (i != 1 && i != widget.totalPages) {
        pageNumbers.add(_pageNumberButton(i, i == widget.currentPage));
      }
    }

    if (widget.currentPage < widget.totalPages - 2) {
      pageNumbers.add(_ellipsisButton());
    }

    if (widget.totalPages > 1) {
      pageNumbers.add(_pageNumberButton(
          widget.totalPages, widget.currentPage == widget.totalPages));
    }

    return pageNumbers;
  }

  Widget _pageNumberButton(int page, bool isActive) {
    final bool isCurrentPage = page == widget.currentPage;

    return MouseRegion(
      onEnter: (_) {
        if (!isCurrentPage) {
          setState(() => _hoveredPage = page);
        }
      },
      onExit: (_) {
        if (_hoveredPage == page) {
          setState(() => _hoveredPage = null);
        }
      },
      child: GestureDetector(
        onTap: isCurrentPage ? null : () => widget.onPageChanged(page),
        child: Container(
          margin: EdgeInsets.symmetric(horizontal: 4),
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isCurrentPage
                ? (widget.isDarkMode ? Colors.grey[700] : Color(0xFF5162F6))
                : (_hoveredPage == page
                    ? Colors.grey[300]
                    : Colors.transparent),
            borderRadius: BorderRadius.circular(4),
            border: isCurrentPage
                ? Border.all(
                    color: widget.isDarkMode ? Colors.grey[500]! : Color(0xFF5162F6),
                    width: 1,
                  )
                : null,
          ),
          child: Text(
            '$page',
            style: TextStyle(
              color: isCurrentPage
                  ? Colors.white
                  : (widget.isDarkMode ? Colors.grey[400] : Colors.grey[600]),
              fontSize: 12,
              fontWeight: isCurrentPage ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  Widget _ellipsisButton() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        '...',
        style: TextStyle(
          color: widget.isDarkMode ? Colors.grey[400] : Colors.grey[600],
          fontSize: 12,
        ),
      ),
    );
  }

  int max(int a, int b) => a > b ? a : b;
  int min(int a, int b) => a < b ? a : b;
}