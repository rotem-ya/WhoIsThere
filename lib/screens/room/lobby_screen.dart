class _RoomCodeCard extends StatelessWidget {
  final String code;
  final bool isCopied;
  final VoidCallback onTap;
  const _RoomCodeCard({required this.code, required this.isCopied, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        // הפיכת הגובה לדינמי לפי התוכן כדי למנוע את ה-Bottom Overflow
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4))],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min, // תופס רק כמה שצריך
          children: [
            Text(isCopied ? 'הועתק!' : 'לחץ להעתקה', style: const TextStyle(fontSize: 14, color: Colors.grey)),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown, // מבטיח שהקוד יתכווץ ולא יחרוג
              child: Text(code, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 4)),
            ),
          ],
        ),
      ),
    );
  }
}
