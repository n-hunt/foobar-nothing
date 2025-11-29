import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SearchView2 extends StatelessWidget {
  const SearchView2({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "SEARCH",
            style: GoogleFonts.shareTechMono(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          TextField(
            style: const TextStyle(color: Colors.white, fontSize: 18),
            decoration: InputDecoration(
              hintText: "TYPE COMMAND...",
              hintStyle: TextStyle(color: Colors.grey[700]),
              enabledBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.white)
              ),
              focusedBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFFD71921))
              ),
            ),
          ),
          const SizedBox(height: 40),
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.auto_awesome, size: 40, color: Colors.grey[800]),
                  const SizedBox(height: 16),
                  Text(
                    "CACTUS AGENT READY",
                    style: TextStyle(color: Colors.grey[700], letterSpacing: 2),
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
