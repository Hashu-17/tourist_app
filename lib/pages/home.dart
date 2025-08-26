import 'package:flutter/material.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(body: 
            Container(child: 
             Stack(children:[
             Image.asset("images/home.png", width: MediaQuery.of(context).size.width, height:MediaQuery.of(context).size.height/2.5, fit: BoxFit.cover,),
             Padding(
               padding: const EdgeInsets.only(top:50.0, right:10.0,),
               child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                 children: [
                   ClipRRect(
                    borderRadius: BorderRadius.circular(25),
                    child: Image.asset("images/user.png", width:50, height: 50, fit: BoxFit.cover,)),
                 ],
               ),
             )
        ],
      ),
     )
    );
  }
}