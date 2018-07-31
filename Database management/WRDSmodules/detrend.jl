using RCall
@rlibrary stlplus

a = mergedDF[35510][:ROEq]
@rput a
R"np = min(c($(c), (length(a) - sum(is.na(a)))/4))"
R"print(np)"
R"b = stlplus::stlplus(a, n.p = np, s.window = 'periodic')"
R"remainder = stlplus::remainder(b)"
@rget remainder

using Plots
plotlyjs()
plot(remainder)
