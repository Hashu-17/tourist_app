import 'package:flutter/material.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: Container(
      child: Stack(children: [
        Image.asset(
          "images/home.png",
          width: MediaQuery.of(context).size.width,
          height: MediaQuery.of(context).size.height / 2.5,
          fit: BoxFit.cover,
        ),
        Padding(
          padding: const EdgeInsets.only(
            top: 50.0,
            right: 10.0,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Material(
                elevation: 3.0,
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(20), // less rounded for a boxy look
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20), // boxy rounded corners
                    gradient: LinearGradient(
                      colors: [
                        Color.fromARGB(255, 186, 247, 244), // light greenish
                        Color.fromARGB(255, 241, 246, 247), // light blue
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  padding: const EdgeInsets.all(4),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16), // match or slightly less than container
                    child: Image.asset(
                      "images/user.png",
                      width: 50,
                      height: 50,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            ],
          ),
        )
      ]),
    ));
  }
}