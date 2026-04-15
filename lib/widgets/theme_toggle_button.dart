import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:careasen/providers/theme_provider.dart';
import 'package:careasen/theme/app_colors.dart';

/// Professional Theme Toggle Button with animated transition
class ThemeToggleButton extends StatelessWidget {
  final bool
      isCompact; // If true, shows only icon. If false, shows icon + label

  const ThemeToggleButton({
    Key? key,
    this.isCompact = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) {
        final isDark = themeProvider.isDarkMode;
        final isDarkTheme = Theme.of(context).brightness == Brightness.dark;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => themeProvider.toggleTheme(),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      transitionBuilder: (child, animation) {
                        return ScaleTransition(scale: animation, child: child);
                      },
                      child: Icon(
                        isDarkTheme ? Icons.dark_mode : Icons.light_mode,
                        key: ValueKey(isDarkTheme),
                        size: 24,
                        color: isDarkTheme
                            ? AppColors.darkPrimary
                            : AppColors.lightPrimary,
                      ),
                    ),
                    if (!isCompact) ...[
                      const SizedBox(width: 8),
                      Text(
                        isDarkTheme ? 'Dark' : 'Light',
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Floating Action Button version for settings
class ThemeToggleFAB extends StatelessWidget {
  const ThemeToggleFAB({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) {
        final isDarkTheme = Theme.of(context).brightness == Brightness.dark;

        return FloatingActionButton(
          onPressed: () => themeProvider.toggleTheme(),
          backgroundColor:
              isDarkTheme ? AppColors.darkPrimary : AppColors.lightPrimary,
          elevation: 4,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (child, animation) {
              return ScaleTransition(scale: animation, child: child);
            },
            child: Icon(
              isDarkTheme ? Icons.light_mode : Icons.dark_mode,
              key: ValueKey(isDarkTheme),
              color: isDarkTheme ? AppColors.darkBackground : Colors.white,
              size: 28,
            ),
          ),
        );
      },
    );
  }
}

/// Professional Theme Toggle Dialog
class ThemeToggleDialog extends StatelessWidget {
  const ThemeToggleDialog({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) {
        final isDarkTheme = Theme.of(context).brightness == Brightness.dark;

        return AlertDialog(
          title: const Text('Choose Theme'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildThemeOption(
                context: context,
                icon: Icons.light_mode,
                label: 'Light Mode',
                isSelected: !isDarkTheme,
                onTap: () {
                  themeProvider.setDarkMode(false);
                  Navigator.pop(context);
                },
              ),
              const SizedBox(height: 12),
              _buildThemeOption(
                context: context,
                icon: Icons.dark_mode,
                label: 'Dark Mode',
                isSelected: isDarkTheme,
                onTap: () {
                  themeProvider.setDarkMode(true);
                  Navigator.pop(context);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  static Widget _buildThemeOption({
    required BuildContext context,
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    final primaryColor =
        isDarkTheme ? AppColors.darkPrimary : AppColors.lightPrimary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? primaryColor : Colors.grey.withOpacity(0.3),
              width: isSelected ? 2 : 1,
            ),
            color:
                isSelected ? primaryColor.withOpacity(0.1) : Colors.transparent,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: isSelected ? primaryColor : Colors.grey,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w400,
                        color: isSelected ? primaryColor : null,
                      ),
                ),
              ),
              if (isSelected)
                Icon(Icons.check_circle, color: primaryColor, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
