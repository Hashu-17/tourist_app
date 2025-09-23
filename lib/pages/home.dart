import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  final List<Map<String, String>> destinations = [
    {
      "name": "LAITLUM",
      "image": "images/laitlum.jpg",
      "visitors": "500+",
      "weather": "Cloudy",
      "temp": "18°C",
    },
    {
      "name": "SOHRA",
      "image": "images/sohra.jpg",
      "visitors": "320+",
      "weather": "Rainy",
    },
    {
      "name": "DAWKI",
      "image": "images/dawki.jpg",
      "visitors": "210+",
      "weather": "Sunny",
    },
    {
      "name": "Ward's Lake",
      "image": "images/wards2.jpg",
      "visitors": "90+",
      "weather": "Sunny",
    },
  ];

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    double screenHeight = MediaQuery.of(context).size.height;

    // Filter destinations based on search query
    final filteredDestinations = _searchQuery.isEmpty
        ? destinations
        : destinations
              .where(
                (place) => place["name"]!.toLowerCase().contains(
                  _searchQuery.toLowerCase(),
                ),
              )
              .toList();

    return Scaffold(
      body: Container(
        color: Colors.black, // Set background to black
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: screenWidth,
                height: screenHeight / 2.5,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final imageHeight = constraints.maxHeight;
                    final imageWidth = constraints.maxWidth;
                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Image.asset(
                          "images/home2.jpg",
                          width: screenWidth,
                          height: screenHeight / 2.5,
                          fit: BoxFit.cover,
                        ),
                        Positioned(
                          top: screenHeight * 0.053,
                          left: screenHeight * 0.017,
                          right: screenHeight * 0.017,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Thematic map icon (inverted colors)
                              Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(20),
                                  onTap: () {
                                    // TODO: Navigate to thematic map page
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.7),
                                      borderRadius: BorderRadius.circular(13),
                                    ),
                                    child: Icon(
                                      Icons.map,
                                      color: Colors.white,
                                      size: 28,
                                    ),
                                  ),
                                ),
                              ),
                              // User icon (inverted colors)
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.7),
                                  borderRadius: BorderRadius.circular(13),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.asset(
                                    "images/user.png",
                                    width: 24,
                                    height: 24,
                                    fit: BoxFit.cover,
                                    color: Colors.white,
                                    colorBlendMode: BlendMode.srcIn,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Positioned(
                          bottom: imageHeight * 0.280,
                          left: imageWidth * 0.05,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "MegTourism",
                                style: TextStyle(
                                  fontSize: kIsWeb ? 48.0 : imageWidth * 0.130,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white,
                                  fontFamily: 'Lato',
                                ),
                              ),
                              Text(
                                "A tourist's guide",
                                style: TextStyle(
                                  fontSize: kIsWeb
                                      ? 20.0
                                      : (imageWidth * 0.05).clamp(12.0, 24.0),
                                  fontWeight: FontWeight.w400,
                                  color: Colors.white,
                                  fontFamily: 'Lato',
                                  height: 1.0, // Use a normal line height
                                ),
                              ),
                            ],
                          ),
                        ),
                        Positioned(
                          bottom: -25,
                          left: screenWidth * 0.08,
                          right: screenWidth * 0.08,
                          child: Material(
                            elevation: 5.0,
                            borderRadius: BorderRadius.circular(30),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                border: Border.all(width: 1),
                                borderRadius: BorderRadius.circular(30),
                              ),
                              child: TextField(
                                controller: _searchController,
                                onChanged: (value) {
                                  setState(() {
                                    _searchQuery = value;
                                  });
                                },
                                decoration: InputDecoration(
                                  border: InputBorder.none,
                                  prefixIcon: Icon(Icons.search),
                                  hintText: 'Search your destination',
                                  hintStyle: TextStyle(
                                    color: Colors.grey,
                                    fontFamily: 'Lato',
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 40),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 15,
                ), // Cards closer to edges
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: filteredDestinations.map((place) {
                    return SizedBox(
                      width: double.infinity,
                      child: Card(
                        margin: const EdgeInsets.only(
                          bottom: 20,
                        ), // Increased gap between cards
                        color: Colors.transparent,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Stack(
                              children: [
                                // Background Image (fills entire card area)
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.asset(
                                    place["image"]!,
                                    width: double.infinity,
                                    height: 260,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                // Dark overlay for readability
                                Container(
                                  height: 260,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.transparent,
                                        Colors.black.withOpacity(0.4),
                                      ],
                                    ),
                                  ),
                                ),
                                // Foreground content
                                Container(
                                  height: 260,
                                  padding: const EdgeInsets.all(15.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          // Place name on the top left
                                          Text(
                                            place["name"]!,
                                            style: const TextStyle(
                                              fontSize: 30,
                                              fontFamily: 'Lato',
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          // Temperature and weather icon on the top right
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.end,
                                            children: [
                                              Text(
                                                place["temp"] ?? "24°C",
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 30,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              if (place["weather"] == "Sunny")
                                                const Icon(
                                                  Icons.wb_sunny,
                                                  color: Colors.white,
                                                  size: 28,
                                                )
                                              else if (place["weather"] ==
                                                  "Cloudy")
                                                const Icon(
                                                  Icons.cloud,
                                                  color: Colors.white,
                                                  size: 28,
                                                )
                                              else if (place["weather"] ==
                                                  "Rainy")
                                                const Icon(
                                                  Icons.grain,
                                                  color: Colors.white,
                                                  size: 28,
                                                )
                                              else
                                                const Icon(
                                                  Icons.help_outline,
                                                  color: Colors.white,
                                                  size: 28,
                                                ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      const Spacer(),
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.people,
                                            color: Colors.white,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            "Visitors today: ${place["visitors"]}",
                                            style: const TextStyle(
                                              color: Colors.white,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.cloud,
                                            color: Colors.white,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            "Weather: ${place["weather"]}",
                                            style: const TextStyle(
                                              color: Colors.white,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
