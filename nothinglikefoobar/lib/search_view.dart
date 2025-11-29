import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SearchView extends StatelessWidget {
  const SearchView({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "SEARCH",
            style: GoogleFonts.dotGothic16(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              letterSpacing: 2.0,
              color: const Color(0xFFFFFFFF),
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            style: GoogleFonts.ibmPlexMono(
              color: const Color(0xFFFFFFFF),
              fontSize: 14,
              letterSpacing: 1.0,
            ),
            decoration: InputDecoration(
              hintText: "TYPE COMMAND...",
              hintStyle: GoogleFonts.ibmPlexMono(
                color: const Color(0xFF8E8E93),
                fontSize: 12,
                letterSpacing: 1.2,
              ),
              enabledBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF1C1C1E))
              ),
              focusedBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFFFF1E1E))
              ),
            ),
          ),
          const SizedBox(height: 40),
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.auto_awesome, size: 40, color: Color(0xFF1C1C1E)),
                  const SizedBox(height: 16),
                  Text(
                    "CACTUS AGENT READY",
                    style: GoogleFonts.ibmPlexMono(
                      color: const Color(0xFF8E8E93),
                      letterSpacing: 2.0,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}