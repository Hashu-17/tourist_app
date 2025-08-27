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
                        Colors.teal.shade100, // light greenish
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
                      width: 40,
                      height: 40,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 149.55, left: 20.0),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            
          Text("MegTour",
          style: TextStyle(
            fontSize: 50.0,
            fontWeight: FontWeight.w500,
            color: Colors.white,fontFamily: 'Lato'
          ),
          ),
          Text("A tourist's guide",
          style: TextStyle(
            fontSize: 20.0,
            fontWeight: FontWeight.w400,
            color: Colors.white,fontFamily: 'Lato',
            height: 0,
           ),
          ),
          ],
         ),
        ),
       Container(
         margin: EdgeInsets.only(left: 30, right: 30, top: MediaQuery.of(context).size.height / 2.8),
         child: Material(
          elevation:5.0,
          borderRadius: BorderRadius.circular(30),
           child: Container(
                 
                 decoration: BoxDecoration(color: Colors.white, border: Border.all(width:1.5),borderRadius: BorderRadius.circular(30)),
  
                 child: TextField(
            decoration: InputDecoration(
              border: InputBorder.none,
              prefixIcon: Icon(Icons.search),
              hintText: 'Search your destination',
              hintStyle: TextStyle(color: Colors.grey,fontFamily: 'Lato'),
            ),
           ),
                ),
         ),
       )
    ],
    ),
  ),
);
  }
}