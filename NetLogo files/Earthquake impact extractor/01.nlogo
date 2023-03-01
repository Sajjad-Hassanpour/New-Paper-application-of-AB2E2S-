;;;;;;;;;;;;;;;new approach for people evacuation behaviour simulation
;;;;;;;;;;;;;;;;;;;;;;;copyright by Sajjad Hassanpour ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;regarding the scale: for maximum quality (10), each pixel/cell/patch is equal to 70 mm (7 cm) in real plan

breed [peoples people]
breed [exits exit]
breed [objects object]
breed [obstacles obstacle]
breed [nodes node]
breed [rooms room]





extensions [nw table bitmap]
globals
[
  average-time
  total-time
  state
  fails
  wins
  peoples-list
  average-path-distance
  speed-min              ;; the minimum speed in roder not to let turtles stop
  speed-limit            ; maximum of speed
  moment
]
exits-own
[

]

rooms-own
[
  sub-nodes
  connections
  utility-function
  rooms-reward
]

peoples-own
[
  my-path
  my-path-length
  manner                  ;;if he is in hurry
  gender                 ;;male/female
  category
  family-member
  receptionist
  initial-place
  familiar
  knowledge
  experience
  nodes-met
  rooms-met
  goal                   ; what he/she wants to do next
  temporary-goal
  current-room
  next-room
  next-node
  panic-level
  injury-level
  speed                  ;;speed of walking
  previous-step
  disutility             ;; all people percept an amount as their satisfaction status due to the position they are in at the time
  options
  area
  follow-state
  group
]
nodes-own
[
  reward  ;;;;default rewards for each step (nodes exits asnd holes)

  temporary-score
  ID
  node-score
  origin
  destination
  path
  location
  dist
  available-exit


]

patches-own
[

  meaning         ;;;;describes about what the patch is (walkway, exit area, partition wall or etc)?
  damage-level     ;;;;describes about what the damage level of the corresponding element ?
  Impact-level      ;;;;describes the impact of the damage state on evacuation process?
  score2          ;; affordances of the patch or distance from the  doors
]

links-own
[
  name
  weight  ;;;;Qmax which should be updated each step
  between
  utility

]

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; set up ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
to setup
  ca
  set-default-shape nodes "nodes"
  draw-world
  set average-time []
  set speed-min  0.08
  set speed-limit 3.0
  ask peoples
  [
    set disutility [score2] of patch-here
  ]
  set peoples-list []
  set wins 0
  set fails 0
  set state "normal"
  ;import-drawing "5 floor croped.jpg"
  reset-ticks
end

to draw-world
  create-environment


end

to create-environment


  let data-set bitmap:import "image4.png"


  ;
  ; print out some debug info about the PNG file
  ;
  let data-width (bitmap:width data-set) / (10 / Visualization-accuracy)
  let data-height (bitmap:height data-set) / (10 / Visualization-accuracy)

  ; print (list "image width = " data-width)
  ; print (list "image height = " data-height)
  ;
  ; scale the NetLogo world to match the PNG data
  ;
  resize-world 0 data-width 0 data-height
  ;
  ; make a smaller patch size so everything fits on the screen
  ;
  set-patch-size 1
  ;
  ; assign the pcolors based on the PNG data values
  ;
  bitmap:copy-to-pcolors data-set true
  ; bitmap:copy-to-drawing data-set 0 0

  ask patches
  [
    ;set pcolor round pcolor
    ifelse pcolor = 9.2 [set meaning "walkway"][set meaning "walls"]



  ]
 ; draw-nodes

end



to check-speed
  if speed < speed-min
  [set speed speed-min]
  if speed > speed-limit
  [set speed speed-limit]

end


;;;;;;;;;;;;;;;;;;;;;;;;;the nodes of perceptual graph
to draw-nodes

  ask patches with [meaning = "walkway"] [if (pxcor mod (nodes-mesh * 5) = 0) and (pycor mod (nodes-mesh * 5) = 0) [sprout-nodes 1
    [set color grey set size 4 set reward []  set node-score []  set available-exit []]]]

 ; ask patches with [meaning = "internal-exits"] [sprout-nodes 1
  ;  [set color grey set size 1 set reward []  set node-score []  set available-exit [] set destination [] set path [] ]]

  let w []
  set w sort-on [who] nodes
  foreach w
  [ the-node -> ask the-node [ set ID  position the-node w ] ]


end

to add-to-network

  set destination [who] of min-one-of nodes with [color = red] [distance myself]       set origin [who] of self

  set location patch-here

    without-interruption
  [
  let the-next-nodes other nodes in-radius (nodes-mesh * 5 * 1.5)
  if the-next-nodes != nobody
  [
    create-links-to the-next-nodes
    [
      if link-length < 2 [die]
      set between (list [location] of end1)

      let l 1
      let m link-heading
      ;set between patch-set k
      while [l < link-length]
      [

        set between fput [patch-at-heading-and-distance m l ] of end1 between

        set l (l + 1)

      ]


      let wall-between (filter [the-patch -> [meaning] of the-patch = "walls"] [between] of self)

      ifelse not empty? wall-between [die]   [set color grey  set weight [] set utility [] ]

    ]


  ]
  ]




end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;manually changing the network



to modify-network

  if mouse-down?
  [ ask patch mouse-xcor mouse-ycor
    [
      ask patches in-radius 4 [
        if (not any? nodes-here) and (meaning = "walkway")
        [
          sprout-nodes 1
          [
            set shape "nodes"
            set size 4
            set color grey
            set reward []  set node-score []  set available-exit []
            ; while [length reward < length peoples-list]
            ;  [set reward lput 0 reward]
            ;set reward map [ i -> nodes-initial-reward ] reward
            ; if show-labels = true
            ; [
            ;  set label who
            ;  set label-color black
            ; ]
            let w []
            set w sort-on [who] nodes
            foreach w
            [ the-node -> ask the-node [ set ID  position the-node w ] ]

            add-to-network
            create-links-from turtle-set [end2] of my-out-links [set color grey  set weight [] set utility [] set name self]

          ]
        ]


      ]
    ]
    ;ask nodes [add-to-network]
  ]


end


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;all nodes find path
to path-finder

  ask-concurrent nodes
  [
    add-to-network

  ]
  ask-concurrent  nodes
  [
    set path nw:path-to node destination
    if path != false
    [
      set dist sum [link-length] of link-set path
    ]
    ; set node-score dist
  ]
  ask-concurrent nodes with [[meaning]of patch-here != "internal-exits"]
  [
    ask my-links [let wall-between (filter [the-patch -> [meaning] of the-patch = "internal-exits"] [between] of self)
    if [meaning] of ([patch-here] of end2) != "internal-exits" and not empty? wall-between [die]]
  ]

  ask links
  [
    if weight = 0 [die]
    while [length weight < length peoples-list]
    [set weight lput 0 weight   set utility lput 0 utility]
    set name self
  ]
  ;ask nodes with [color != red] [set reward map [ i -> nodes-initial-reward ] reward]


end

to check-network
  path-finder


  ask nodes
  [
    set available-exit []

    let exit-nodes [who] of nodes with [color = red]
    foreach exit-nodes [ x -> set available-exit (fput node x  available-exit)]


    while [ (path = false) and (not empty? available-exit)]
    [
      set destination [who] of min-one-of turtle-set available-exit [distance myself]
      set path nw:path-to node destination
      set available-exit remove node destination available-exit
    ]

    if path != false
    [
      set dist sum [link-length] of link-set path
    ]



  ]
  ask patches with [meaning = "walkway" or meaning = "exits" ] [ set score2 distance min-one-of nodes with [color = red] [distance myself] ]
  ask patches with [meaning != "walkway" and meaning != "exits" ] [ set score2 1000]

end

to modify-paths

  ask nodes with [path = false]
  [
    die
  ]

  ask nodes
  [
    set path []
    set destination []
  ]
end

to test
  if any? nodes with [path = false]
  [
    user-message (word "there are some nodes which are not connected to the whole network; add more nodes around them or delete them by clicking on (delete unconnected nodes) button")
  ]

end

to hide-labels

  ask nodes
  [
    ifelse label = ""
    [
      set label who
    ]
    [
      set label ""
    ]
  ]

end



to hide-links

  ifelse (count links with [hidden? = false] > 0) and (count links with [hidden? = true] > 0)
  [ask links [set hidden? true]]
  [

    ask links [set hidden? not hidden?]
  ]

end

to add-walls
  if mouse-down?
  [

    ask patch mouse-xcor mouse-ycor

    [
      if meaning = "internal-exits"
      [
      set meaning "walls"
      set pcolor white
      ask turtles-here [die]
      ]
     ; if not any? turtles-here [sprout 1 [set shape "square" set color blue - 1 ]]

    ]


  ]


end

to add-furniture
  if mouse-down?
  [

    ask patch mouse-xcor mouse-ycor

    [
      ask patches in-radius 4
      [
        set meaning "walls"
        set pcolor grey
        ask nodes-here [die]
        if not any? turtles-here [sprout 1 [set shape "square" set color grey ]]
      ]
    ]


  ]

end

to delete-walls
  if mouse-down?
  [

    ask patch mouse-xcor mouse-ycor

    [
      set meaning "walkway"
      set pcolor 9.2
      ask turtles-here [die]

    ]


  ]


end


to add-exits
 if mouse-down?
  [ ask patch mouse-xcor mouse-ycor
    [




      if meaning = "walls" or meaning = "exits" and  (not any? turtles-here)
      [
        set meaning "exits"
        set pcolor yellow

        sprout 1
        [
          set heading 0
          if v/h = "H" [rt 90]
          let x 1
          while [x < door-width] [ask patch-ahead x [if meaning = "walls" or meaning = "exits" [set pcolor yellow set meaning "exits" sprout 1 [set color red  ifelse v/h = "H" [set heading 0] [set heading 90]]]] set x x + 1  ]
         ; repeat door-width [fd 1 ask patch-here [if meaning = "walls" or meaning = "internal-exit" [set pcolor yellow set meaning "internal-exit"        ]]]

          ifelse v/h = "H" [set heading 0] [set heading 90]
set color red
          ]
          sprout 1
          [
            set heading 0
          ifelse V/H = "H" [rt -90] [rt 180]
          let x 1
          while [x < door-width] [ask patch-ahead x [if meaning = "walls" or meaning = "exits" [set pcolor yellow set meaning "exits" sprout 1 [set color red  ifelse v/h = "H" [set heading 0] [set heading 90]]]] set x x + 1  ]
        ;  repeat door-width [fd 1 ask patch-here [ if meaning = "walls" or meaning = "internal-exit" [set pcolor yellow set meaning "internal-exit" ]]]
set color red
           ifelse v/h = "H" [set heading 0] [set heading 90]
          ]
        ]


      ]
    ]

end

to add-internal-exits
  if mouse-down?
  [ ask patch mouse-xcor mouse-ycor
    [




      if meaning = "walls" or meaning = "internal-exits" and  (not any? turtles-here)
      [
        set meaning "internal-exits"
        set pcolor yellow

        sprout 1
        [
          set heading 0
          if v/h = "H" [rt 90]
          let x 1
          while [x < door-width] [ask patch-ahead x [if meaning = "walls" or meaning = "internal-exits" [set pcolor yellow set meaning "internal-exits" sprout 1 [set color red  ifelse v/h = "H" [set heading 0] [set heading 90]]]] set x x + 1  ]
         ; repeat door-width [fd 1 ask patch-here [if meaning = "walls" or meaning = "internal-exit" [set pcolor yellow set meaning "internal-exit"        ]]]

          ifelse v/h = "H" [set heading 0] [set heading 90]
set color red
          ]
          sprout 1
          [
            set heading 0
          ifelse V/H = "H" [rt -90] [rt 180]
          let x 1
          while [x < door-width] [ask patch-ahead x [if meaning = "walls" or meaning = "internal-exits" [set pcolor yellow set meaning "internal-exits" sprout 1 [set color red  ifelse v/h = "H" [set heading 0] [set heading 90]]]] set x x + 1  ]
        ;  repeat door-width [fd 1 ask patch-here [ if meaning = "walls" or meaning = "internal-exit" [set pcolor yellow set meaning "internal-exit" ]]]
set color red
           ifelse v/h = "H" [set heading 0] [set heading 90]
          ]
        ]


      ]
    ]



end

to define-rooms
  while [count nodes with [color = grey] != 0 ]
  [
  ask one-of nodes with [color = grey]
    [        ask one-of neighbors with [meaning = "walkway"]
    [
     add-room
  ]
  ]

  ]



  ; ask nodes with [[meaning] of patch-here = "internal-exits"] [foreach room [k -> if member? ([who] of [end2] of my-out-links) ([sub-nodes] of room k)  [set [sub-nodes] of room k lput [who] of myself [sub-nodes] of room k]]]

end

to add-room
   if  (meaning = "walkway") and (not any? nodes-here) and (not any? rooms-here)
      [
        sprout-rooms 1
        [
          set size 10
          set sub-nodes []
          set shape "house"
          if color = red or color = grey [set color blue]
          set sub-nodes lput min-one-of nodes [distance myself] sub-nodes

          if sub-nodes != nobody
          [
            let removed-members [1]
              while [length sub-nodes = length removed-members ]
            [
            set sub-nodes lput turtle-set [link-neighbors] of ((turtle-set sub-nodes) with [[meaning] of patch-here != "internal-exits"]) sub-nodes
              set removed-members remove-duplicates sub-nodes
            ]

            set utility-function []
            set rooms-reward []
            set sub-nodes turtle-set [sub-nodes] of self
            ask sub-nodes [
              set hidden? false if color != red [set color [color] of myself ]

            ]


          ]


          if any? nodes
          [
            create-links-to nodes
            [
              set hidden? true
              set between (list [patch-here] of end1)

              let l 1
              let m link-heading
              while [l < link-length]
              [

                set between fput [patch-at-heading-and-distance m l ] of end1 between

                set l (l + 1)

              ]

              let wall-between (filter [the-patch -> ([meaning] of the-patch = "walls") or ([meaning] of the-patch = "internal-exits") or ([meaning] of the-patch = "exits")] [between] of self)

              if not empty? wall-between [die]

            ]
            set utility-function []
            set rooms-reward []
            set sub-nodes link-neighbors
            ask sub-nodes [set hidden? false if color != red [set color [color] of myself ]]
            ask my-links [die]

          ]

      ]
        ]

end


to main-connections
  ask rooms [set sub-nodes sort sub-nodes]
  ask rooms
  [
    foreach ([who] of nodes with [[meaning] of patch-here = "internal-exits" or [meaning] of patch-here = "exits"]) [x -> if member? node x ([end2] of link-set [my-out-links] of turtle-set sub-nodes)    [set sub-nodes lput node x (sub-nodes) ]]
    if who = 124 [  set sub-nodes (filter [x -> ([ycor] of x < 27) and ([ycor] of x > 18)]  sub-nodes)  set sub-nodes lput (one-of nodes with [xcor = 75 and ycor = 21]) sub-nodes  ]
    if who = 115 [  set sub-nodes (filter [x -> ([ycor] of x < 38)] sub-nodes)  ]
    if who = 136 [  set sub-nodes (filter [x -> ([ycor] of x > 25)] sub-nodes)  ]
    if who = 114 [  set sub-nodes (filter [x -> ([ycor] of x > 38)] sub-nodes)  ]

    if who = 727 [  set sub-nodes (filter [x -> ([ycor] of x < 27) and ([ycor] of x > 18)]  sub-nodes)  set sub-nodes lput (one-of nodes with [xcor = 75 and ycor = 21]) sub-nodes  ]
    if who = 718 [  set sub-nodes (filter [x -> ([ycor] of x < 38)] sub-nodes)  ]
    if who = 739 [  set sub-nodes (filter [x -> ([ycor] of x > 25)] sub-nodes)  ]
    if who = 717 [  set sub-nodes (filter [x -> ([ycor] of x > 38)] sub-nodes)  ]

    let the-list [who] of other rooms
    set connections []
    foreach  sub-nodes [x -> foreach the-list [k -> if member? x  [sub-nodes] of room k [set connections lput k connections]] ]

    set connections remove-duplicates connections
    foreach connections
    [
      x -> create-link-to room x
      [

        set between (list [patch-here] of end1)

        let l 1
        let m link-heading
        while [l < link-length]
        [

          set between fput [patch-at-heading-and-distance m l ] of end1 between

          set l (l + 1)

        ]


        set weight []
        set utility []

      ]
    ]
    ask turtle-set [other-end] of my-links
    [
      create-link-to myself
      [

        set between (list [patch-here] of end1)

        let l 1
        let m link-heading
        while [l < link-length]
        [

          set between fput [patch-at-heading-and-distance m l ] of end1 between

          set l (l + 1)

        ]


        set weight []
        set utility []

      ]
    ]

  ]
end


to generate-people

  let entering-areas patch-set [neighbors] of (patches with [meaning = "exits"])


  if  random-exponential (inter-arrival-time) < 0.1 [
    ask one-of entering-areas with [meaning = "walkway"] [if not any? peoples-here [
      sprout-peoples (1 + floor random 1.05)
      [
        if any? other peoples-here [die]
        set-attributes
        set receptionist one-of peoples with [category = "personnel"]
        if random-float 1 < 0.2
        [
          set category "family" set color green
          ask one-of neighbors with [meaning = "walkway" and not any? other peoples-here]
          [sprout-peoples 1 [ set-attributes set receptionist one-of peoples with [category = "personnel"] set color green set category "family"]]
          let partner one-of (peoples-on neighbors) with [category = "family" and family-member = 0]
          ifelse partner != nobody
          [
            set family-member partner
            ask partner [set family-member myself]
          ]
          [die]

        ]


      ]

      ]
    ]
  ]


end

to earthquake
  set state "shaking"
  ask patches with [meaning = "walls" and damage-level = 1]
  [
    ask patches in-radius random (4 + (2 * (Visualization-accuracy / 5)))
    [
    if meaning = "walkway"
    [
      if (random-normal  0 0.2) > 0.70 and damage-level < 1  [set damage-level 1]

      set pcolor (29.9 - (damage-level * 1.9))
    ]
  ]
  ]

    ask patches with [meaning = "walls" and damage-level = 2]
  [
    ask patches in-radius random (10 + (2 * (Visualization-accuracy / 5)))
    [
    if meaning = "walkway"
    [
      if (random-normal  0 0.2) > 0.50 and damage-level < 1  [set damage-level 1]
      if (random-normal  0 0.2) > 0.70 and damage-level < 2 [set damage-level 2 ]

      set pcolor (29.9 - (damage-level * 1.9))
    ]
  ]
  ]



    ask patches with [meaning = "walls" and damage-level = 3]
  [
    ask patches in-radius random (16 + (2 * (Visualization-accuracy / 5)))
    [
    if meaning = "walkway"
    [
      if (random-normal  0 0.2) > 0.30 and damage-level < 1  [set damage-level 1]
      if (random-normal  0 0.2) > 0.50 and damage-level < 2 [set damage-level 2 ]
      if (random-normal  0 0.2) > 0.70 and damage-level < 3 [set damage-level 3 ]

      set pcolor (29.9 - (damage-level * 1.9))
    ]
  ]
  ]

;;;;;ceiling impacts OR acceleration impacts
  ask rooms
  [
   ask sub-nodes
    [
      ask (patch-set patch-here patches in-radius 15) with [meaning = "walkway"]
      [
        if (random-normal  0 0.2) > (0.8 / acceleration) [set damage-level damage-level + random 3]
        if damage-level > 5 [set damage-level 5]
        set pcolor (29.9 - (damage-level * 1.9))
      ]

    ]
  ]
  ask patches with [meaning = "walls" and pcolor = 48.4]
  [
     ask  patches in-radius 15 with [meaning = "walkway"]
      [
        if (random-normal  0 0.2) > (0.8 / acceleration) [set damage-level damage-level + random 3]
        if damage-level > 5 [set damage-level 5]
        set pcolor (29.9 - (damage-level * 1.9))
      ]
  ]






 ; ask patches with [meaning = "walkway"]
  ;[
   ; if (random-normal  0 0.2) > 0.35 [set damage-level damage-level + random 3]
    ;if damage-level > 5 [set damage-level 5]
    ;set pcolor (29.9 - (damage-level * 1.9))
  ;]
  ask patches with [damage-level = 2] [ask peoples-here [if panic-level < 1 [set panic-level 1]]]
  ask patches with [damage-level = 3] [ask peoples-here [if injury-level < 1 [set injury-level 1] ] ask peoples in-radius 2 [if panic-level < 1 [set panic-level 1]]]
  ask patches with [damage-level = 4] [ask peoples in-radius 2 [ if injury-level < 1 [set injury-level 1 ]] ask peoples in-radius 3 [if panic-level < 1 [set panic-level 1]] ask peoples in-radius 1 [if panic-level < 2 [set panic-level 2]]]
  ask patches with [damage-level = 5] [ask peoples in-radius 4 [if injury-level < 1 [set injury-level 1] ] ask peoples-here [if injury-level < 2 [set injury-level 2] set manner "dead"] ask peoples in-radius 3 [if panic-level < 2 [set panic-level 2]]]
  ask peoples [if (sum [damage-level] of neighbors > 8) or (any? peoples in-radius 1 with [manner = "dead"]) [set panic-level (panic-level + 1) if panic-level > 2 [set panic-level 2]]]

end




to add-agents

  if mouse-down?
  [ ask patch mouse-xcor mouse-ycor
    [
      if  (meaning = "walkway") and (not any? peoples-here)
      [
        sprout-peoples 1
        [
          set-attributes
          set receptionist one-of peoples with [category = "personnel"]
          if random-float 1 < 0.1
          [
            set category "family" set color green
            ask one-of neighbors with [meaning = "walkway" and not any? other peoples-here]
            [sprout-peoples 1 [ set-attributes set receptionist one-of peoples with [category = "personnel"] set color green set category "family"]]
            let partner one-of (peoples-on neighbors) with [category = "family" and family-member = 0]
            ifelse partner != nobody
            [
              set family-member partner
              ask partner [set family-member myself]
            ]
            [die]

          ]
        ]
      ]
    ]
  ]


end

to set-attributes
  set initial-place patch-here
  set gender "men"
  set shape "people2"
  set manner "earthquake"
  set size 8
  set color grey
  set category "visitor"
  set familiar "yes"
  set panic-level 0
  set injury-level 0
  let c (random-normal mean-speed-of-men 0.15) / 2
  ;;; it is assumed that the speed is distributed randomly among men with the mean of 0.25 and standard deviation of 0.15 which can be changed
  set speed c
  check-speed
  set temporary-goal []
  set my-path []
  set nodes-met []
  set rooms-met []
  set experience []
  set peoples-list lput self peoples-list
  let v sort link-set [my-links] of rooms
  let r random (length  v)
  set experience n-of r v
 ; set knowledge (count link-set experience / count link-set [my-out-links] of rooms) * 100
  ask links [while [length weight < length peoples-list]   [set weight lput 0 weight  set utility lput 0 utility]  ]
  ask nodes [while [length node-score < length peoples-list] [set node-score lput 0 node-score set reward lput 0 reward set destination lput 0 destination set path lput 0 path]]
  ask rooms [while [length utility-function < length peoples-list] [set utility-function lput 0 utility-function set rooms-reward lput 0 rooms-reward]]
  ;set-goal
  set follow-state "alone"
  set current-room []
  ;find-first-room
  set group [] set group lput self group
  ;set-next-room
  ;update-next-node

end


to find-first-room
  set current-room []
  let nearest-node min-one-of nodes [distance myself]
  ask my-links [die]

  without-interruption
  [
    create-link-to nearest-node
    [
      ;set hidden? true
      if [patch-here] of end1 = [patch-here] of end2 [die]
      set between []
      let l 1
      let m link-heading
      while [l < link-length]
      [

        set between fput [patch-at-heading-and-distance m l ] of end1 between

        set l (l + 1)

      ]


      let wall-between (filter [the-patch -> [meaning] of the-patch = "obstacle" or [meaning] of the-patch = "walls" ] [between] of self)

      if not empty? wall-between [die]
      set weight []
      set utility []

    ]
    if count my-links = 0 and ticks = 0 [ die]
  ]
  ask my-links [die]


  foreach [who] of rooms [x -> if member? nearest-node [sub-nodes] of room x  [set current-room lput room x current-room ]]
  if empty? current-room and ticks = 0 [die]
  set current-room one-of current-room
  set rooms-met lput current-room rooms-met
  find-current-space

end

to find-current-space
  let p1 (turtle-set ([sub-nodes] of current-room)) with [([pcolor] of patch-here != yellow) and color != red]
  let p2 (turtle-set ([sub-nodes] of current-room))
  let area1 (patch-set [neighbors] of p1)
  set area1 area1 with [meaning = "walkway"]
  let area2 (patch-set ([neighbors] of (area1 with [not any? nodes-here]) )) with [meaning = "walkway"]
  set area (patch-set area2 (patch-set [patch-here] of p2) )
  set area remove-duplicates sort area
  set area patch-set area
end

to set-next-room
  let n position self peoples-list
  if next-room != 0 [set rooms-met lput next-room rooms-met]



  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; LOGIT model for the link choice (How can I code the stochastic choice now that I have the probability in hand?????????????????/)
  ;;;;;;;;;?????????????????????????????


  let y  [my-out-links] of current-room

  set y link-set y
  ask  y
  [
    ;;;;;;;avoid zero at Denominator
    ifelse (sum  [exp item n weight] of y) = 0 [set utility replace-item n utility (exp item n weight / 0.001)]
    ;;;;;;; choice model (Logit model)
    [set utility replace-item n utility  (exp  item n weight / (sum  [exp item n weight] of y)) ]
  ]



  set next-room max-one-of turtle-set [end2] of link-set y [(item n rooms-reward) * 2 - (distance myself / 100)]
  if next-room = nobody [set y  link-set [my-out-links] of current-room set next-room max-one-of turtle-set [end2] of link-set y [(item n rooms-reward) * 2 - (distance myself / 100)] ]


  set-temporary-goal

  set nodes-met []

end

to set-temporary-goal
  let w (turtle-set ([sub-nodes] of current-room)) with [[meaning] of patch-here = "internal-exits" or [meaning] of patch-here = "exits"]
  let temporary-door []
  foreach sort w [x -> if member? x [sub-nodes] of next-room [set temporary-door lput x temporary-door]]
  set temporary-goal min-one-of turtle-set temporary-door [distance myself]

end

to update-route-utility

  let n position self peoples-list
  let o link ([who] of last rooms-met) ([who] of next-room)
  let o' link ([who] of next-room)  ([who] of last rooms-met)
  let next-link (link-set o o')

  ;if show-links = true [ask next-link  [    set color red set hidden? false set thickness 0.1  ]]
  set my-path lput o my-path
  ;set my-path lput (link ([who] of next-node)  ([who] of first nodes-met)) my-path
  set my-path-length sum [link-length] of link-set my-path
  set my-path lput o' my-path





  ;;;;;;;;;;;;;;;;;;;;;;;;;normal nodes q learning update
  if o != nobody [
    ask o
    [

      let Qmax'  max ([item n weight] of [my-links] of end2)
      let Q-value  ( (1 - alpha) * (item n weight) + alpha * ( ([item n rooms-reward] of end2  )  + gamma * Qmax') )
      set weight replace-item n weight Q-value

    ]

  ]



end


to set-goal

  ;;select one of the main goals
  let n position self peoples-list
  set goal nodes with [color = red]
  ;ask nodes in-radius people-sight [set hidden? false]
  ask nodes
  [
    set reward replace-item n reward nodes-initial-reward
  ]
  ask goal
  [
    set reward replace-item n reward goals-initial-reward
  ]
  ask rooms
  [
    set rooms-reward replace-item n rooms-reward (sum [item n reward] of (turtle-set sub-nodes) / count (turtle-set sub-nodes))
  ]
  ask rooms
  [
    let y  sort [end2] of my-out-links
    set rooms-reward replace-item n rooms-reward ((item n rooms-reward + sum [item n rooms-reward] of turtle-set y) / (length y + 1))
  ]

end



to go

  ;people-movement
  ifelse ticks < (eql-sec)

  [

    earthquake

  ]


  [
    stop ;; added for this version just for earthquaek
    set state "evacuation"
    ask peoples with [manner = "earthquake"][set manner "evacuate"]
    ifelse pen = true [ask peoples [pen-down]]  [ask peoples [pen-up]]


    if count peoples with [hidden? = false and manner != "dead" and manner != "stuck"] = 0
    [
      set total-time ticks * 0.3
      stop
    ]



    if state = "normal"
    [
      if count peoples with [category = "personnel"] < 2 [
        user-message (word  "There should be at least two Personnels to give services. you can use 'Add Personnel' to add some personnel into some rooms")
        stop
      ]
      generate-people
    ]
  ]

  tick

end



to people-movement

  ask peoples with [manner = "evacuate" or (manner = "earthquake" and panic-level = 2)]
  [
    if not member? patch-here area [ set-goal find-first-room set-next-room set nodes-met [] update-next-node]

    ifelse (category = "family" and family-member != nobody and ([hidden?] of family-member = false) and [manner] of family-member != "dead" and [manner] of family-member != "stuck")
    [reunite ]
    [

      navigate

      if [meaning] of patch-here = "exits"
      [
        update-route-utility
        set wins wins + 1
        set manner "done"
        set hidden? true
        set average-time lput (ticks * 0.3) average-time
        move-to patch 168 0
      ]
    ]
  ]
  ask peoples with [manner = "normal"]
    [

      if category = "personnel" [if any? peoples with [(category = "visitor") or (category = "family")] in-radius 3 [face min-one-of (peoples with [(category = "visitor") or (category = "family")])  [distance myself]]]
      if (category = "visitor") or (category = "family") [normal-navigation]
      if category = "security" []

  ]


end


to reunite

  set-goal
  let n position self peoples-list
  if not member? next-node ([sub-nodes] of current-room) [update-next-node]

  ifelse distance family-member < 2 [set category "united" set-goal set-next-room  ]
  [
    ifelse current-room = [current-room] of family-member [set temporary-goal family-member set-direction]
    [

      ask [current-room] of family-member
      [
        set rooms-reward replace-item n rooms-reward (goals-initial-reward)
      ]
      ask rooms
      [
        let y  sort [end2] of my-out-links
        set rooms-reward replace-item n rooms-reward ((item n rooms-reward + sum [item n rooms-reward] of turtle-set y) / (length y + 1))
      ]

      let z  [my-out-links] of current-room
      set z link-set z
      set next-room max-one-of turtle-set [end2] of z [item n rooms-reward ]

      set-temporary-goal
      ifelse not member? (one-of nodes-here) ([sub-nodes] of next-room)
      [set-direction]
      [
        set experience lput link [who] of next-room [who] of current-room experience
        set knowledge (knowledge + (count link-set experience / count link-set [my-out-links] of rooms) * 100)  if knowledge > 100 [set knowledge 100]
        if next-room != last rooms-met [set rooms-met lput next-room rooms-met]
        set current-room next-room find-current-space   update-route-utility reunite
      ]
    ]
  ]


end


to check-group
  let available-space (patch-set area) in-radius people-sight with [meaning = "walkway" or meaning = "exits" or meaning = "internal-exits"]
  let potential-group sort(peoples-on available-space)
  let potential-group2 filter [i -> not member? i group] potential-group
  if (not empty? potential-group2) [set-group]
  if empty? potential-group [set group [] set group lput self group set follow-state "alone" ]

end


to normal-navigation

  let n position self peoples-list
  if not member? next-node ([sub-nodes] of current-room) [update-next-node]

  ifelse distance receptionist < 2.5 [ set receptionist one-of peoples with [category = "personnel"] if length rooms-met > random 10 [set manner "evacuate" set-goal set-next-room stop] ]
  [
    ifelse current-room = [current-room] of receptionist [set temporary-goal receptionist set-direction]
    [
      ;set goal [nodes in-radius 2] of receptionist
      ask rooms [set rooms-reward replace-item n rooms-reward 0]
      ask [current-room] of receptionist
      [

        set rooms-reward replace-item n rooms-reward (goals-initial-reward)
      ]
      ask rooms
      [
        let y  sort [end2] of my-out-links
        set rooms-reward replace-item n rooms-reward ((item n rooms-reward + sum [item n rooms-reward] of turtle-set y) / (length y + 1))
      ]


      ;set next-room min-one-of
      let z  [my-out-links] of current-room
      set z link-set z

      set next-room max-one-of turtle-set [end2] of z [item n rooms-reward ]
      if next-room = nobody [set z  link-set [my-out-links] of current-room set next-room max-one-of turtle-set [end2] of link-set z [item n rooms-reward ] ]

      set-temporary-goal

      ifelse not member? (one-of nodes-here) ([sub-nodes] of next-room)
      [set-direction]
      [
        set experience lput link [who] of next-room [who] of current-room experience
        set knowledge (knowledge + (count link-set experience / count link-set [my-out-links] of rooms) * 100)  if knowledge > 100 [set knowledge 100]
        if next-room != last rooms-met [set rooms-met lput next-room rooms-met]
        set current-room next-room find-current-space   update-route-utility normal-navigation
      ]
    ]
  ]

end


to navigate

  if not member? next-node ([sub-nodes] of current-room) [update-next-node]
  if count neighbors with [damage-level > 3] > 7 [set panic-level 2 set manner "stuck"]
  if state = "shaking" and ([damage-level] of patch-here > 2) [if injury-level < 1 [set injury-level  1]]
  if state = "shaking" and ([damage-level] of patch-here > 3) [set injury-level (injury-level + 1) if injury-level > 2 [set injury-level 2 set manner "dead" ]]
  ifelse not member? (one-of nodes-here) ([sub-nodes] of next-room)


  [
    set-direction

  ]

  [
    set experience lput link [who] of next-room [who] of current-room experience
    set knowledge (knowledge + (count link-set experience / count link-set [my-out-links] of rooms) * 100)  if knowledge > 100 [set knowledge 100]
    set current-room next-room find-current-space   set-next-room   update-route-utility set-direction
  ]

end


to set-direction
  let n position self peoples-list
  let group-speed [speed] of min-one-of turtle-set group [speed]
  let available-space area in-radius people-sight with [meaning = "walkway" or meaning = "exits" or meaning = "internal-exits" ]
  ;let best-patch neighbors with [meaning = "walkway" or meaning = "exits" or meaning = "internal-exits" and damage-level < 5 and not any? (peoples-here with [manner != "dead"])]
  if next-node != nobody
  [
    ifelse next-node =  temporary-goal or distance next-node <= (nodes-mesh * 5 * 2) and not any? (peoples-on [patch-here] of next-node) with [manner = "dead"]
    [

      ifelse patch-here != [patch-here] of next-node
      [
        ifelse available-space != nobody
        [
          ifelse panic-level = 2 [carefully [face min-one-of available-space  [distance [next-node] of myself] action ] [  fd 0 ]]
          [carefully [face min-one-of available-space  [distance [next-node] of myself + (damage-level ^ 2 / 8)] action ] [  fd 0 ]  ] ]
        [fd 0]
      ]
      [
        update-next-node
        ifelse available-space != nobody
        [
          ifelse panic-level = 2 [carefully [face min-one-of available-space  [distance [next-node] of myself] action ] [  fd 0 ]]
          [carefully [face min-one-of available-space  [distance [next-node] of myself + (damage-level ^ 2 / 8)] action ] [ fd 0 ]  ] ]
        [fd 0]

      ]

    ]

    [
      ifelse distance next-node < (people-sight / 2)
      [ update-next-node
        ifelse available-space != nobody
        [
          ifelse panic-level = 2 [carefully [face min-one-of available-space  [distance [next-node] of myself] action ] [  fd 0 ]]
          [ carefully [face min-one-of available-space  [distance [next-node] of myself + (damage-level ^ 2 / 8)] action] [ fd 0 ]  ] ]
        [fd 0]
      ]
      [
        ifelse available-space != nobody
        [
          ifelse panic-level = 2 [carefully [face min-one-of available-space  [distance [next-node] of myself] action ] [ fd 0 ]]
          [carefully [face min-one-of available-space  [distance [next-node] of myself + (damage-level ^ 2 / 8)] action ] [ fd 0 ]  ] ]
        [fd 0]
      ]

    ]
  ]
  ; create-link-to  next-node [set color red]
  ;set disutility [score2] of patch-here
end


to follow-leader
  let n position self peoples-list
  let group-speed [speed] of min-one-of turtle-set group [speed]
  let follow-space patches in-radius people-sight with [meaning = "walkway" or meaning = "exits" or meaning = "internal-exits" ]
  let best-patch neighbors with [(meaning = "walkway" or meaning = "exits" or meaning = "internal-exits") and (not any? peoples-here) ]
  set best-patch filter  [x -> member? x [area]of myself] best-patch
  if next-node != nobody [
    ifelse patch-here != [patch-here] of next-node
    [
      ifelse follow-space != nobody
        [carefully [face min-one-of follow-space  [distance [next-node] of myself] action ] [ fd 0 ]  ] [fd 0]
    ]
    [
      update-next-node
      ifelse follow-space != nobody
        [carefully [face min-one-of follow-space  [distance [next-node] of myself] action] [ fd 0 ]  ] [fd 0]

    ]
  ]



  ;set disutility [score2] of patch-here
end




to action
  let group-speed [speed] of (min-one-of turtle-set group [speed])

  if state = "normal" [set group-speed group-speed / 4 ]
  if panic-level = 2 [set group-speed speed ]
  if injury-level = 1 [set group-speed group-speed / 1.5]
  let best-patch neighbors with [(meaning = "walkway" or meaning = "exits" or meaning = "internal-exits") and damage-level < 5 and (not any? peoples-here) and (distance [next-node] of myself < [previous-step] of myself + 0.5 ) ]
  ;set best-patch remove patch-here best-patch


  ifelse best-patch != nobody
        [
          ifelse panic-level = 2 [carefully [face min-one-of best-patch [distance [next-node] of myself] fd (group-speed * 1.5 / ([damage-level] of patch-here + 1)) ] [  fd 0 ]]
          [carefully [face min-one-of best-patch  [distance [next-node] of myself + (damage-level ^ 2 / 16)] fd (group-speed / ([damage-level] of patch-here + 1)) ] [ fd 0 ]  ] ]
  [fd 0 ]






  set disutility [score2] of patch-here

  set previous-step distance next-node



end

to avoid

  let available-space (patch-set patch-ahead 1 patch-left-and-ahead 90 1 patch-right-and-ahead 90 1 )
  let best-patch one-of available-space with [not any? peoples-here]
  ifelse (best-patch != nobody)
  [

    face best-patch
    ;;we should check if the randomly destributed speed of people doesn't pass teh max and min limitations
    fd speed
  ]
  [fd 0 ]


  ;set available-space available-space with [meaning = "walkway" or meaning = "exits" or meaning = "internal-exits"]
  ;set available-space available-space with [not any? peoples-here]


end


to set-group
  set group []
  ask my-links [die]

  let available-space (patch-set area) in-radius people-sight with [meaning = "walkway" or meaning = "exits" or meaning = "internal-exits"]
  let potential-group sort other peoples-on available-space
  set group (potential-group)


  ifelse not empty? group
  [
    set group lput self group

    ask turtle-set group [set follow-state "follower"  set group lput myself group   set group remove-duplicates group]
    ;ask max-one-of turtle-set group [knowledge] [set follow-state "leader"]
  ]
  [set follow-state "alone" set group lput self group ]
  ;ask peoples with [follow-state = "alone"] [set color grey]
  ; ask peoples with [follow-state = "leader"] [set color blue ]
  ;ask peoples with [follow-state = "follower"] [set color orange ]

end


to update-next-node



  let leader one-of (other turtle-set group) with [color = blue]
  if leader = nobody [set leader max-one-of (other turtle-set group) [knowledge]]
  let n position self peoples-list
  no-display
  ask my-links [die]
  let available-space (patch-set area) in-radius people-sight with [meaning = "walkway" or meaning = "exits" or meaning = "internal-exits"]

  set nodes-met fput next-node nodes-met
  let y nodes-on available-space
  set y (filter [the-node ->  member? the-node ([sub-nodes] of current-room)] (sort y))
  if not empty? but-first nodes-met [
    let kh (list first nodes-met first but-first nodes-met)
    set y (filter [the-node -> not member? the-node kh] (sort y))
  ]




  create-links-to turtle-set y
    [
      ;set hidden? true
      if [patch-here] of end1 = [patch-here] of end2 [die]
      set between []

      let l 1
      let m link-heading
      while [l < link-length]
      [

        set between fput [patch-at-heading-and-distance m l ] of end1 between

        set l (l + 1)

      ]


      let wall-between (filter [the-patch -> [meaning] of the-patch = "obstacle" or [meaning] of the-patch = "walls" ] [between] of self)

      if not empty? wall-between [die]
      set weight []
      set utility []

  ]



  set options turtle-set link-neighbors
  carefully [set next-node min-one-of (options) [distance [temporary-goal] of myself + ([damage-level] of patch-here) / 2]][ set-next-room]
  if next-node =  nobody [set-goal find-first-room set-next-room ask my-links [die] set nodes-met [] face min-one-of neighbors with [meaning = "walkway"] [damage-level] fd speed  ]
  ask my-links [die]
  display

  ; evaluate

end

to damage
  if mouse-down?
  [

    ask patch mouse-xcor mouse-ycor

    [
      ask patches in-radius 4
      [
        if pcolor != (29.9 - (ns-damage-level * 1.9))
        [
          set damage-level ns-damage-level
          set pcolor (29.9 - (damage-level * 1.9))

          ask nodes-here [
            set node-score map [ i -> i + (damage-level * 2) ] node-score

          ]
        ]
      ]
    ]
    ask nodes
    [
      set temporary-score sum [damage-level] of ([neighbors] of patch-here)
    ]

  ]

end



to reset
  reset-ticks
  plot-pen-reset
  ask peoples
  [
    reset-peoples

  ]
end


to reset-peoples


  pen-up
  move-to initial-place
  set manner "earthquake"
  set hidden? false
  set nodes-met []

  ask link-set my-path [set color grey]
  ;; choosing the first next node


  set next-room 0
  set current-room []
  set my-path []
  set rooms-met []
  find-first-room
  set-next-room
  set follow-state "alone"
  ;set color grey
  update-next-node
  ;set-group
  ;set experience []




end




to clear
  cd
end

to kill
  reset-ticks
  ask peoples [die]
end

to save

  nw:save-gdf "network-smaller"

end

to load

  nw:load-gdf "network-smaller" nodes links

end

to just-map
  ask turtles [die]
end

;;;;;;;;copyright by Sajjad Hassanpour ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;; Ph.D. candidate of Emam Khomeini university, research visitor, university of Auckland ;;;;;;;;;;a
@#$#@#$#@
GRAPHICS-WINDOW
0
520
752
743
-1
-1
1.0
1
10
1
1
1
0
0
0
1
0
743
0
213
0
0
1
ticks
50.0

BUTTON
2
10
213
142
Setup/Load the layout
setup\n\ndraw-nodes\n\ndefine-rooms\n\nask rooms [set hidden? true]\nask nodes [set hidden? true]\n\nask patches with [meaning = \"walkway\"]\n[set pcolor white]
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
222
12
426
143
Go
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
596
150
738
183
women-percent
women-percent
0
100
19.0
0.5
1
percent
HORIZONTAL

SLIDER
501
113
725
146
mean-speed-of-women
mean-speed-of-women
0
4
0.0
0.01
1
m/s
HORIZONTAL

SLIDER
500
44
709
77
mean-speed-of-men
mean-speed-of-men
0
3
3.0
0.01
1
m/s
HORIZONTAL

SWITCH
1101
173
1191
206
pen
pen
1
1
-1000

CHOOSER
240
451
378
496
method
method
"cellular" "graph mode" "QL"
0

INPUTBOX
912
142
994
202
num-of-objects
0.0
1
0
Number

SLIDER
826
10
859
140
nodes-mesh
nodes-mesh
1
10
4.0
1
1
NIL
VERTICAL

BUTTON
96
304
178
344
reset peoples 
reset
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
725
42
823
75
add some nodes
modify-network
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
1330
43
1436
76
delete unconnected nodes
modify-paths
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
1330
10
1435
43
test connectivity
test
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
1165
10
1270
47
show/hide links
hide-links
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
875
105
988
138
remove people
kill\nset fails 0\nset wins 0
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
499
11
709
44
people-sight
people-sight
1
500
303.0
1
1
meters in radius
HORIZONTAL

BUTTON
1165
48
1270
81
show/hide labels
hide-labels
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
1880
357
1986
390
save network
\n  nw:save-graphml \"mesh6\"
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
105
415
168
448
NIL
clear
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
862
10
997
70
add a visitor
add-agents
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

MONITOR
278
358
432
403
Overal number of people 
count peoples
17
1
11

MONITOR
1874
254
1987
299
number of objects
count objects with [hidden? = false]
17
1
11

BUTTON
739
143
827
176
kill objects
ask objects [die]
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
725
74
822
107
remove nodes
if mouse-down?\n[ask patch mouse-xcor mouse-ycor\n[ask nodes-here [die]]]
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

MONITOR
1876
300
1982
345
number of nodes
count nodes with [[meaning] of patch-here != \"exit\"]
17
1
11

BUTTON
1165
82
1271
115
show/hide nodes
ask nodes [set hidden? not hidden?]
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
833
147
915
180
add an object
 if mouse-down?\n  [ ask patch mouse-xcor mouse-ycor\n    [\n    if (not any? turtles-here) and (meaning = \"walkway\") \n      [\n        sprout-objects 1\n        [ set color brown\n        set size 2\n        set shape \"box\"\n        let the-next-nodes other turtles with [breed = nodes or breed = objects] in-radius (nodes-mesh * 1.5)\n    if the-next-nodes != nobody\n    [\n      create-links-to the-next-nodes\n      [\n        set hidden? true\n\n        set between (list [patch-here] of end1)\n\n        let l 1\n        let m link-heading\n        while [l < link-length]\n        [\n\n          set between fput [patch-at-heading-and-distance m l ] of end1 between\n\n          set l (l + 1)\n\n        ]\n\n\n        set between (filter [the-patch -> [meaning] of the-patch = \"walls\"] [between] of self)\n\n        if not empty? between [die]\n\n      ]\n\n\n    ]]\n        ]\n        ]\n        ]
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

MONITOR
1872
207
1988
252
number of evacuees
count peoples with [hidden? = true]
17
1
11

SLIDER
1502
132
1674
165
alpha
alpha
0
1
0.9
0.1
1
NIL
HORIZONTAL

SLIDER
1502
164
1674
197
gamma
gamma
0
1
0.7
0.1
1
NIL
HORIZONTAL

TEXTBOX
1730
81
2124
165
QL:\n\nQ(s,a) <- (1-alpha) * Q(s,a) + alpha*(R(s) + gamma * max [Q(s', a')] )\n\n
11
0.0
1

SLIDER
1544
23
1716
56
nodes-initial-reward
nodes-initial-reward
-8
8
-6.0
0.1
1
NIL
HORIZONTAL

PLOT
593
204
1177
497
plot 1
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot count peoples with [hidden? = true]"
"pen-1" 1.0 0 -955883 true "" "plot count peoples with [injury-level = 1]"
"pen-2" 1.0 0 -2674135 true "" "plot count peoples with [injury-level = 2]"

SLIDER
1502
98
1674
131
fails-initial-reward
fails-initial-reward
-100
100
-68.0
1
1
NIL
HORIZONTAL

SLIDER
1501
64
1673
97
goals-initial-reward
goals-initial-reward
-100
100
50.0
1
1
NIL
HORIZONTAL

MONITOR
1728
455
1809
500
NIL
fails
17
1
11

MONITOR
1726
504
1808
549
NIL
wins
17
1
11

BUTTON
1001
10
1153
43
add walls 
add-walls
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
1277
77
1487
110
get ready after changing the layout
check-network
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
1005
106
1155
139
add exit doors
add-exits
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
1002
73
1155
106
delete walls or obstacles
delete-walls
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SWITCH
862
71
996
104
full-information
full-information
0
1
-1000

BUTTON
1002
42
1154
75
add furniture or obstacles
add-furniture
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
725
10
823
43
create mesh
\ndraw-nodes\npath-finder\n;check-network\nmodify-paths
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
1358
222
1464
280
clear the plan
clear-drawing
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
726
107
823
140
clear mesh
ask nodes with [color = grey] [die]
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
1388
286
1451
319
save
nw:save-graphml \"doors.graphml\"
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
1350
320
1485
353
Analyze the layout
nw:load-graphml \"doors.graphml\"\nask-concurrent nodes with [color =  yellow][ask patch-here [set pcolor yellow set meaning \"internal-exits\" ] \nif count nodes in-radius nodes-mesh > 1 [die]]\nask nodes with [color =  red][ask patch-here [set pcolor red set meaning \"exits\"]]\nask nodes [set reward []  set node-score []  set available-exit []]\n\ndraw-nodes\npath-finder\n;check-network\nmodify-paths\n\ndefine-rooms\nmain-connections\nask rooms [ask my-links [set hidden? true]]
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
1334
118
1491
151
non-structural damage
damage
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
1334
151
1491
184
ns-damage-level
ns-damage-level
0
5
5.0
1
1
NIL
HORIZONTAL

BUTTON
1360
185
1468
218
reset damage
ask patches with[meaning = \"walkway\"] [set pcolor white]\nask patches [set damage-level 0]
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
97
266
180
299
sub goals
 if mouse-down?\n  [ ask patch mouse-xcor mouse-ycor\n    [\nask nodes-here [set color orange set size 1.5]\n]\n]\n
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
0
148
106
181
Ceiling panels
define-rooms
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
117
148
250
181
space connections
main-connections
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
0
440
108
473
internal doors
add-internal-exits
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
1371
353
1484
386
reload damage
ask patches with [meaning = \"walls\"] [set damage-level 0]\n\nimport-pcolors \"Damage Scenario 3(final new paper)2022.png\"\n\nask patches with [meaning = \"walls\"]\n[\n\nif (pcolor < 49.3 and pcolor > 48.7) [set damage-level 1]\nif (pcolor < 44.9 and pcolor > 44.4) [set damage-level 2]\nif (pcolor < 27.8 and pcolor > 26.1)[set damage-level 3]\nif (pcolor = 25.6 or pcolor = 28.2)[set damage-level 3]\n\n]\n\n let data-set bitmap:import \"image4.png\"\n\n\n  ;\n  ;\n  bitmap:copy-to-pcolors data-set true\n \n
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
426
154
590
187
Insert architectural plan
 import-drawing \"5 floor croped.jpg\"
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
1231
237
1310
356
Scenario 1
\ndraw-nodes\n\nask rooms\n[\n  \n          if any? nodes \n          [\n            create-links-to nodes\n            [\n              set hidden? true\n              set between (list [patch-here] of end1)\n\n              let l 1\n              let m link-heading\n              while [l < link-length]\n              [\n\n                set between fput [patch-at-heading-and-distance m l ] of end1 between\n\n                set l (l + 1)\n\n              ]\n\n              let wall-between (filter [the-patch -> ([meaning] of the-patch = \"walls\") or ([meaning] of the-patch = \"internal-exits\") or ([meaning] of the-patch = \"exits\")] [between] of self)\n\n              if not empty? wall-between [die]\n\n            ]\n            set utility-function []\n            set rooms-reward []\n            set sub-nodes link-neighbors\n            ask sub-nodes [set hidden? false if color != red [set color [color] of myself ]]\n            ask my-links [die]\n\n          ]\n]\n\nmain-connections\nask links [set hidden? true]\nask nodes [set hidden? true]\nask room 124 [  set sub-nodes (filter [x -> ([ycor] of x < 27) and ([ycor] of x > 18)]  sub-nodes)    ]\nask room 115 [  set sub-nodes (filter [x -> ([ycor] of x < 38)] sub-nodes)  ]\nask room 114 [  set sub-nodes (filter [x -> ([ycor] of x > 38)] sub-nodes)  ]\nask room 136 [  set sub-nodes (filter [x -> ([ycor] of x > 25)] sub-nodes)  ]\nask rooms [set hidden? true]\n\nclear-drawing
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

MONITOR
1817
448
1888
493
nodes met
length [nodes-met] of people 3611
17
1
11

BUTTON
450
226
561
259
Add Personnel
\n  if mouse-down?\n  [ ask patch mouse-xcor mouse-ycor\n    [\n      if  (meaning = \"walkway\") and (not any? peoples-here)\n      [\n        sprout-peoples 1\n        [\n          set-attributes\n          set color blue\n          set category \"personnel\"\n         \n\n        ]\n      ]\n    ]\n  ]\n
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
453
260
554
293
add Security
\n  if mouse-down?\n  [ ask patch mouse-xcor mouse-ycor\n    [\n      if  (meaning = \"walkway\") and (not any? peoples-here)\n      [\n        sprout-peoples 1\n        [\n          set-attributes\n          set color orange\n          set category \"security\"\n         \n\n        ]\n      ]\n    ]\n  ]\n
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
996
170
1079
203
Evacuate
set state \"evacuation\"\nask peoples [set manner \"evacuate\" set-goal]
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
501
75
710
108
inter-arrival-time
inter-arrival-time
0.5
30
8.5
0.5
1
seconds
HORIZONTAL

MONITOR
12
267
93
312
NIL
state
17
1
11

PLOT
1516
205
1872
449
plot 2
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot count peoples with [hidden? = false]"
"pen-1" 1.0 0 -408670 true "" "plot count peoples with [hidden?  = false and panic-level = 1]"
"pen-2" 1.0 0 -955883 true "" "plot count peoples with [hidden?  = false and  panic-level = 2]"
"pen-3" 1.0 0 -4539718 true "" "plot count peoples with [hidden?  = false and  injury-level = 1]"
"pen-4" 1.0 0 -1069655 true "" "plot count peoples with [injury-level = 2]"
"pen-5" 1.0 0 -2674135 true "" "plot count peoples with [manner = \"dead\"]"

BUTTON
458
188
547
221
add a man
if mouse-down?\n  [ ask patch mouse-xcor mouse-ycor\n    [\n      if  (meaning = \"walkway\") and (not any? peoples-here)\n      [\n        sprout-peoples 1\n        [\n          set-attributes\n         \n      ]\n    ]\n  ]\n  ]
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

MONITOR
266
310
316
355
average knowledge
sum [knowledge] of peoples / (count peoples)
17
1
11

SWITCH
273
149
390
182
emergency
emergency
0
1
-1000

BUTTON
18
199
113
258
Earthquake
earthquake
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

INPUTBOX
114
198
164
258
eql-sec
10.0
1
0
Number

BUTTON
91
344
183
377
quick reset
ask patches with [meaning = \"walkway\"]  [ set damage-level 0 set pcolor (29.9 - (damage-level * 1.9))]\nreset-ticks\nask peoples [die]\nset state \"normal\"
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
77
377
208
410
random personnel
\n ask rooms\n [\n ask one-of sub-nodes\n    [\n    ask patch-here\n    [\n      if  (meaning  = \"walkway\") and (not any? peoples-here)\n      [\n        sprout-peoples 1\n        [\n          set-attributes\n          set color blue\n          set category \"personnel\"\n         \n\n        ]\n      ]\n    ]\n    ]\n  ]\n \n
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

MONITOR
265
263
375
308
svere injury or deaths
count peoples with [manner = \"dead\"]
17
1
11

MONITOR
318
309
375
354
scared
count peoples with [panic-level = 1]
17
1
11

MONITOR
376
265
433
310
injured
count peoples with [injury-level = 1]
17
1
11

MONITOR
377
311
434
356
paniced
count peoples with [panic-level = 2]
17
1
11

BUTTON
168
199
318
257
Insert random people
while [count peoples < number-of-people]\n[\nask one-of patches with [meaning = \"walkway\" and (not any? peoples-here)]\n    [      \n        sprout-peoples 1\n        [ \n        \n        \n          set-attributes\n          set receptionist one-of peoples with [category = \"personnel\"]\n          if random-float 1 < 0.1\n          [\n            set category \"family\" set color green\n            ask one-of neighbors with [meaning = \"walkway\" and not any? other peoples-here]\n            [sprout-peoples 1 [ set-attributes set receptionist one-of peoples with [category = \"personnel\"] set color green set category \"family\"]]\n            let partner one-of (peoples-on neighbors) with [category = \"family\" and family-member = 0]\n            ifelse partner != nobody\n            [\n            set family-member partner\n            ask partner [set family-member myself]\n            ]\n            [die]\n\n        ]\n      ]\n      \n    \n  ]\n  ]\n ; Ask-Concurrent peoples [set-next-room]
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

INPUTBOX
319
198
417
258
number-of-people
50.0
1
0
Number

MONITOR
278
404
432
449
Number of evacuated people
count peoples with [hidden? = true]
17
1
11

MONITOR
387
452
529
497
number of stuck people
count peoples with [manner = \"stuck\"]
17
1
11

BUTTON
1230
117
1312
235
Scenario 2
nw:load-graphml \"example7.graphml\"\nask rooms  [set color cyan]\nask patches [if any? turtles-here with [color = red] [set meaning \"exits\" set pcolor red]]\nask patches [if any? turtles-here with [color = yellow] [set meaning \"internal-exits\" set pcolor yellow] ask nodes-here [die]]\nask patches [if any? turtles-here with [color = blue - 1] [set meaning \"walls\" set pcolor blue ask turtles-here [set heading 0]]]\nask patches [if any? turtles-here with [color = grey and breed != nodes and breed != rooms] [set meaning \"walls\" set pcolor grey + 1 ask turtles-here [set heading 0]]]\nask patches with [pcolor = red] [ask nodes-here [die] if (not any? nodes-here) [ sprout-nodes 1\n        [\n\n          set shape \"nodes\"\n          ;set size 1.5\n          set color red\n          set reward []\n           while [length reward < length peoples-list]\n            [set reward lput 0 reward]\n          ;set reward map [ i -> exits-initial-reward ] reward\n          set dist 0\n          ; set hidden? True\n          \n          ]\n          \n        ]\n      ]\n      ask nodes with [color = red] [\n      set node-score []\n      \n      add-to-network\n          create-links-from turtle-set [end2] of my-out-links [set color grey  set weight [] set utility [] set name self\n\n            while [length weight < length peoples-list]\n            [set weight lput 0 weight  set utility lput 0 utility]\n]]\n\ndraw-nodes\ncheck-network\nmodify-paths\nask rooms\n[\n  \n          if any? nodes \n          [\n            create-links-to nodes\n            [\n              set hidden? true\n              set between (list [patch-here] of end1)\n\n              let l 1\n              let m link-heading\n              while [l < link-length]\n              [\n\n                set between fput [patch-at-heading-and-distance m l ] of end1 between\n\n                set l (l + 1)\n\n              ]\n\n              let wall-between (filter [the-patch -> ([meaning] of the-patch = \"walls\") or ([meaning] of the-patch = \"internal-exits\") or ([meaning] of the-patch = \"exits\")] [between] of self)\n\n              if not empty? wall-between [die]\n\n            ]\n            set utility-function []\n            set rooms-reward []\n            set sub-nodes link-neighbors\n            ask sub-nodes [set hidden? false if color != red [set color [color] of myself ]]\n            ask my-links [die]\n\n          ]\n]\n\nmain-connections\nask links [set hidden? true]\nask nodes [set hidden? true]\n\nask room 727 [  set sub-nodes (filter [x -> ([ycor] of x < 27) and ([ycor] of x > 18)]  sub-nodes)    ]\nask room 718 [  set sub-nodes (filter [x -> ([ycor] of x < 38)] sub-nodes)  ]\nask room 717 [  set sub-nodes (filter [x -> ([ycor] of x > 38)] sub-nodes)  ]\nask room 739 [  set sub-nodes (filter [x -> ([ycor] of x > 25)] sub-nodes)  ]\n\nask rooms [set hidden? true]\n\nclear-drawing
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

MONITOR
443
304
587
349
average damage
mean [damage-level] of (patches with [meaning = \"walkway\"])
17
1
11

MONITOR
440
350
590
395
average evacuation time
sum average-time / length average-time
17
1
11

MONITOR
127
461
194
506
Total time
Total-time
17
1
11

SLIDER
432
10
465
135
Visualization-accuracy
Visualization-accuracy
1
10
5.0
1
1
NIL
VERTICAL

INPUTBOX
14
320
64
380
door-width
7.0
1
0
Number

CHOOSER
0
393
92
438
V/H
V/H
"H" "V"
1

BUTTON
0
475
104
508
finalize doors
ask turtles with [color = red and heading = 0]\n[\n\nask patch-here [sprout 1 \n[\nset color red\nset heading 180\nwhile [([meaning] of patch-ahead 1) = \"walls\"] \n[\nfd 1 \nask patch-here [set pcolor yellow set meaning \"internal-exits\"]\n]\n\n]\n]\nwhile [([meaning] of patch-ahead 1) = \"walls\"] \n[\nfd 1 \nask patch-here [set pcolor yellow set meaning \"internal-exits\"]\n]\n]\nask turtles with [color = red and heading = 90]\n[\n\nask patch-here [sprout 1 \n[\nset color red\nset heading -90\nwhile [([meaning] of patch-ahead 1) = \"walls\"] \n[\nfd 1 \nask patch-here [set pcolor yellow set meaning \"internal-exits\"]\n]\n\n]\n]\nwhile [([meaning] of patch-ahead 1) = \"walls\"] \n[\nfd 1 \nask patch-here [set pcolor yellow set meaning \"internal-exits\"]\n]\n]
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
1017
139
1133
172
finalize xit door
ask turtles with [color = red and heading = 0]\n[\n\nask patch-here [sprout 1 \n[\nset color red\nset heading 180\nwhile [([meaning] of patch-ahead 1) = \"walls\"] \n[\nfd 1 \nask patch-here [set pcolor yellow set meaning \"exits\"]\n]\n\n]\n]\nwhile [([meaning] of patch-ahead 1) = \"walls\"] \n[\nfd 1 \nask patch-here [set pcolor yellow set meaning \"exits\"]\n]\n]\nask turtles with [color = red and heading = 90]\n[\n\nask patch-here [sprout 1 \n[\nset color red\nset heading -90\nwhile [([meaning] of patch-ahead 1) = \"walls\"] \n[\nfd 1 \nask patch-here [set pcolor yellow set meaning \"exits\"]\n]\n\n]\n]\nwhile [([meaning] of patch-ahead 1) = \"walls\"] \n[\nfd 1 \nask patch-here [set pcolor yellow set meaning \"exits\"]\n]\n]
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

MONITOR
1301
405
1358
450
DS1
count patches with [damage-level = 1 and meaning = \"walls\"]
17
1
11

MONITOR
1361
405
1418
450
DS2
count patches with [damage-level = 2 and meaning = \"walls\"]
17
1
11

MONITOR
1422
405
1479
450
DS3
count patches with [damage-level = 3 and meaning = \"walls\"]
17
1
11

BUTTON
1200
366
1319
399
show damage colors
ifelse not any? patches with [pcolor = yellow and meaning = \"walkway\"]\n[\n\n\n\nask patches with [damage-level = 1][set pcolor yellow]\nask patches with [damage-level = 2][set pcolor orange]\nask patches with [damage-level = 3][set pcolor red]\nask patches with [damage-level > 3][set pcolor red - damage-level]\n\n]\n[\n\nask patches with [meaning = \"walkway\"][set pcolor (29.9 - (damage-level * 1.9))]\n]
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

MONITOR
1212
455
1279
500
Impact>3
count patches with [damage-level > 3]
17
1
11

MONITOR
452
399
560
444
Damage per cent
count patches with [meaning = \"walkway\" and damage-level > 0] / count patches with [meaning = \"walkway\"]
17
1
11

MONITOR
1301
455
1363
500
Impact 1
count patches with [damage-level = 1 and meaning = \"walkway\"]
17
1
11

MONITOR
1365
454
1427
499
Impact 2
count patches with [damage-level = 2 and meaning = \"walkway\"]
17
1
11

MONITOR
1430
456
1492
501
Impact 3
count patches with [damage-level = 3 and meaning = \"walkway\"]
17
1
11

INPUTBOX
185
257
254
317
acceleration
1.76
1
0
Number

INPUTBOX
195
318
245
378
drift
1.0
1
0
Number

@#$#@#$#@
## WHAT IS IT?

(a general understanding of what the model is trying to show or explain)

## HOW IT WORKS

(what rules the agents use to create the overall behavior of the model)

## HOW TO USE IT

(how to use the model, including a description of each of the items in the Interface tab)

## THINGS TO NOTICE

(suggested things for the user to notice while running the model)

## THINGS TO TRY

(suggested things for the user to try to do (move sliders, switches, etc.) with the model)

## EXTENDING THE MODEL

(suggested things to add or change in the Code tab to make the model more complicated, detailed, accurate, etc.)

## NETLOGO FEATURES

(interesting or unusual features of NetLogo that the model uses, particularly in the Code tab; or where workarounds were needed for missing features)

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

## CREDITS AND REFERENCES

(a reference to the model's URL on the web if it has one, as well as any other necessary credits, citations, and links)
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

men
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

nodes
true
0
Circle -7500403 true true 0 0 300
Circle -13791810 true false 30 30 240
Circle -7500403 true true 60 60 178
Circle -13791810 true false 105 105 90

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

people
true
1
Circle -13840069 true false 0 75 150
Circle -13840069 true false 45 45 210
Circle -13840069 true false 135 75 150
Polygon -7500403 true false 150 135
Polygon -2674135 true true 150 45 75 225 150 210 225 225

people2
true
10
Polygon -7500403 true false 297 184 302 167 301 149 289 138 273 126 262 120 256 136 256 145 260 167 269 182 286 191
Polygon -7500403 true false 6 182 1 165 2 147 14 136 30 124 44 119 47 134 47 143 43 165 34 180 17 189
Polygon -7500403 true false 236 118 240 109 229 99 220 92 205 87 188 81 166 87 162 97
Polygon -7500403 true false 77 113 66 115 70 95 77 90 91 84 108 78 132 86 136 92
Polygon -13345367 true true 17 149 9 165 9 176 15 188 25 199 34 207 46 217 59 226 69 235 81 244 98 249 119 255 138 257 158 258 188 256 205 254 223 248 238 236 251 226 259 222 266 216 274 209 282 198 291 185 296 175 295 164 291 152 285 146 276 139 270 133 258 124 242 113 228 105 211 97 194 92 174 93 153 94 133 93 121 91 103 94 84 103 67 115 49 126 39 133 25 143 12 155
Polygon -7500403 true false 150 165
Polygon -7500403 true false 135 210
Polygon -16777216 true false 84 192 100 223 127 244 170 246 207 230 226 191 224 159 212 126 190 109 158 108 122 113 102 126 85 158 82 176
Polygon -7500403 true false 101 127 118 111 140 103 169 105 193 108 205 118 209 124 191 132 160 123 134 124 119 128 109 142
Polygon -7500403 true false 25 113
Polygon -16777216 true false 120 45 195 45 150 0 105 45 120 45

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

women
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 165 75 285 105 285 135 285 150 285 165 285 195 285 225 285 180 165 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.1.1
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@
