import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../theme/app_theme.dart';

class CustomTextField extends StatelessWidget {
  final String hintText;
  final TextEditingController controller;
  final bool obscureText;
  final TextInputType keyboardType;
  final Function(String)? onChanged;

  const CustomTextField({
    super.key,
    required this.hintText,
    required this.controller,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      onChanged: onChanged,
      style: Theme.of(context).textTheme.bodyLarge,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: Theme.of(context).textTheme.bodyLarge,
      ),
    );
  }
}

class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final Color backgroundColor;
  final Color textColor;
  final double borderRadius;

  const CustomButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.backgroundColor = AppTheme.buttonColor,
    this.textColor = AppTheme.primaryColor,
    this.borderRadius = 15.0,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: backgroundColor,
        foregroundColor: textColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        padding: const EdgeInsets.symmetric(vertical: 15.0),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: textColor,
            ),
      ),
    );
  }
}

class AppLogo extends StatelessWidget {
  final double fontSize;

  const AppLogo({
    super.key,
    this.fontSize = 48.0,
  });

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(context).textTheme.displayLarge?.copyWith(
          fontSize: fontSize,
        );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'sca',
          style: textStyle,
        ),
        Text(
          'N',
          style: textStyle?.copyWith(
            color: Colors.blue,
          ),
        ),
        Text(
          'go',
          style: textStyle,
        ),
      ],
    );
  }
}

class SocialLoginButton extends StatelessWidget {
  final String iconPath;
  final VoidCallback onPressed;

  const SocialLoginButton({
    super.key,
    required this.iconPath,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      child: Container(
        width: 60,
        height: 60,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: AppTheme.greyColor,
        ),
        child: Center(
          child: SvgPicture.asset(
            iconPath,
            width: 30,
            height: 30,
          ),
        ),
      ),
    );
  }
}

class CustomDivider extends StatelessWidget {
  final String text;

  const CustomDivider({
    super.key,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: Divider(
            color: AppTheme.accentColor,
            thickness: 1,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        const Expanded(
          child: Divider(
            color: AppTheme.accentColor,
            thickness: 1,
          ),
        ),
      ],
    );
  }
}

class PinKeypad extends StatelessWidget {
  final Function(String) onKeyPressed;

  const PinKeypad({
    super.key,
    required this.onKeyPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildKeypadButton(context, '1'),
              _buildKeypadButton(context, '2'),
              _buildKeypadButton(context, '3'),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildKeypadButton(context, '4'),
              _buildKeypadButton(context, '5'),
              _buildKeypadButton(context, '6'),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildKeypadButton(context, '7'),
              _buildKeypadButton(context, '8'),
              _buildKeypadButton(context, '9'),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildKeypadButton(context, 'X', color: Colors.grey),
              _buildKeypadButton(context, '0'),
              _buildKeypadButton(context, '>', color: Colors.purple),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKeypadButton(BuildContext context, String value,
      {Color? color}) {
    return InkWell(
      onTap: () => onKeyPressed(value),
      child: Container(
        width: 70,
        height: 70,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color ?? Colors.transparent,
        ),
        child: Center(
          child: Text(
            value,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: color != null ? Colors.white : AppTheme.accentColor,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
      ),
    );
  }
}

class CustomBottomNavigationBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const CustomBottomNavigationBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.darkBlueColor,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(context, 'Home', 'assets/icons/home.svg', 0),
            _buildNavItem(context, 'Add Bus', 'assets/icons/add_bus.svg', 1),
            _buildNavItem(context, 'Ticket', 'assets/icons/ticket.svg', 2),
            _buildNavItem(context, 'History', 'assets/icons/history.svg', 3),
            _buildNavItem(context, 'Profile', 'assets/icons/profile.svg', 4),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(
      BuildContext context, String label, String iconPath, int index) {
    final isSelected = currentIndex == index;
    return InkWell(
      onTap: () => onTap(index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(2),
            decoration: isSelected
                ? null
                : BoxDecoration(
                    border: Border.all(
                      color: AppTheme.lightGreyColor,
                      width: 1.5,
                    ),
                    borderRadius: BorderRadius.circular(6),
                  ),
            child: SvgPicture.asset(
              iconPath,
              width: isSelected ? 24 : 20,
              height: isSelected ? 24 : 20,
              colorFilter: ColorFilter.mode(
                isSelected ? AppTheme.primaryColor : AppTheme.lightGreyColor,
                BlendMode.srcIn,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: isSelected
                      ? AppTheme.primaryColor
                      : AppTheme.lightGreyColor,
                ),
          ),
        ],
      ),
    );
  }
}
