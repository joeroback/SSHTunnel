# SSHTunnel TODO

* Write and generate HeaderDoc documentation.

* In the future, support bind port == 0, which means for each tunnel
  feature out a free port to listen on, store in dictionary, after
  connection notification, bind ports can be retrieved from userInfo dict
  in notification or use the forwardTunnels/reverseTunnels getter methods.

* Turn rangeOfStrings to NSPredicates or use hostname/port in range string,
  see [NSPredicates evaluateWithObject:substitutionVariables:], rangeOfString
  is probably fastest, unless this causes a problem, then maybe leave it as-is.

* Support graceful cleanup of open SSH sessions when application wrongfully
  terminates.
