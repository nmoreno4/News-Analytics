module helperFunctions

export loadPaths, defineSpec

function loadPaths(machine)
  if machine == "local"
      rootpath = "/home/nicolas/CodeGood/Data Inputs"
      datarootpath = "/home/nicolas/Data"
      logpath = "/home/nicolas/CodeGood/log"
  elseif machine == "CECI"
      # print(machine)
      rootpath = "/CECI/home/ulg/affe/nmoreno/CodeGood/Data Inputs"
      datarootpath = "/CECI/home/ulg/affe/nmoreno/Data"
      logpath = "/CECI/home/ulg/affe/nmoreno/CodeGood/log"
  end
  return (rootpath, datarootpath, logpath)
end #fun


function defineSpec(factor, sizeQ=0)
  if factor=="10by10"
      Specification = [("ptf_10by10_size_value", parse(Float64,"$(sizeQ).0")), ("ptf_10by10_size_value", parse(Float64,"$(sizeQ).1")),
                       ("ptf_10by10_size_value", parse(Float64,"$(sizeQ).2")), ("ptf_10by10_size_value", parse(Float64,"$(sizeQ).3")),
                       ("ptf_10by10_size_value", parse(Float64,"$(sizeQ).4")), ("ptf_10by10_size_value", parse(Float64,"$(sizeQ).5")),
                       ("ptf_10by10_size_value", parse(Float64,"$(sizeQ).6")), ("ptf_10by10_size_value", parse(Float64,"$(sizeQ).7")),
                       ("ptf_10by10_size_value", parse(Float64,"$(sizeQ).8")), ("ptf_10by10_size_value", parse(Float64,"$(sizeQ).9"))]
  elseif factor=="5by5"
      Specification = [("ptf_5by5_size_value", parse(Float64,"$(sizeQ).1")),    ("ptf_5by5_size_value", parse(Float64,"$(sizeQ).2")),
                       ("ptf_5by5_size_value", parse(Float64,"$(sizeQ).3")), ("ptf_5by5_size_value", parse(Float64,"$(sizeQ).4")),
                       ("ptf_5by5_size_value", parse(Float64,"$(sizeQ).5"))]
  elseif factor=="all"
    Specification = [("HML", ["H", "M", "L"])]
  elseif factor=="Ranks_beme"
    Specification = [("Ranks_beme", 10), ("Ranks_beme", 1)]
  elseif factor=="ptf_2by3_size_value"
    Specification = [("ptf_2by3_size_value", "HH"), ("ptf_2by3_size_value", "LH"),
                     ("ptf_2by3_size_value", "HL"), ("ptf_2by3_size_value", "LL")]
  elseif factor=="ptf_2by3_size_Inv"
    Specification = [("ptf_2by3_size_Inv", "HH"), ("ptf_2by3_size_Inv", "LH"),
                     ("ptf_2by3_size_Inv", "HL"), ("ptf_2by3_size_Inv", "LL")]
  elseif factor=="ptf_2by3_size_OP"
    Specification = [("ptf_2by3_size_OP", "HH"), ("ptf_2by3_size_OP", "LH"),
                     ("ptf_2by3_size_OP", "HL"), ("ptf_2by3_size_OP", "LL")]
  elseif factor=="ptf_2by3_size_MOM"
    Specification = [("ptf_2by3_size_MOM", "HH"), ("ptf_2by3_size_MOM", "LH"),
                     ("ptf_2by3_size_MOM", "HL"), ("ptf_2by3_size_MOM", "LL")]
  elseif factor=="SMB"
    Specification = [("SMB", "L"), ("SMB", "H")]
  elseif factor=="HML"
    Specification = [("HML", "L"), ("HML", "H")]
  elseif factor=="Inv"
    Specification = [("Inv", "L"), ("Inv", "H")]
  elseif factor=="OP_Prof"
    Specification = [("OP_Prof", "L"), ("OP_Prof", "H")]
  elseif factor=="Ranks_momentum"
    Specification = [("Ranks_momentum", 10), ("Ranks_momentum", 1)]
  end
  return Specification
end #fun


end #module
