module nanHandling

export nanmean, nancount, nonnancount, nansum, nanindex, removeonlyNaNrows, avgNaNmat

function nanmean(A::Array)
  #a .!isnan 4
  s, n = 0.0, 0
	for val in A
		if !isnan(val)
			s += val
			n += 1
		end
	end
	return s / n
end #fun
function nancount(A::Array)
  n = 0
	for val in A
		if isnan(val)
			n += 1
		end
	end
	return n
end #fun
function nonnancount(A::Array)
  n = 0
	for val in A
		if !isnan(val)
			n += 1
		end
	end
	return n
end #fun
function nansum(A::Array)
  s = 0.0
	v = []
	if length(size(A))==1
		for val in A
			if !isnan(val)
				s += val
			end
		end
		return s
	elseif length(size(A))==2
		for row in 1:size(A,1)
			push!(v, nansum(A[row,:]))
		end
		return v
	end
end #fun
function nanindex(x, nonnan = false)
  x = Array{Number}(x)
	if nonnan
		x = find(x -> !(isnan.(x)),x)
	else
		x = find(x -> isnan.(x),x)
	end
	return x
end #fun

"""
"""
function avgNaNmat(mat)
  TS = Float64[]
  for row in 1:size(mat, 1)
    push!(TS, nanmean(mat[row,:]))
  end #for row
  return TS
end


"""
Remove rows of matrix where all elements are NaNs.\n
Works for 2-D, 3-D and 4-D Arrays
Typical use is to remove non-trading days.\n
Starts from second column onwards to ignore date.
"""
function removeonlyNaNrows(mat)
  # Send in without a dates column
  tokeep = Int[]
	toremove = Int[]
  for row in 1:size(mat,1)
	  if length(size(mat))==2
	  	if nonnancount(mat[row,:])>0
			  push!(tokeep, row)
			else
				push!(toremove, row)
	    end
	  elseif length(size(mat))==3
  		if nonnancount(mat[row,:,:])>0
  		  push!(tokeep, row)
			else
				push!(toremove, row)
  		end
  	 elseif length(size(mat))==4
  		if nonnancount(mat[row,:,:,:])>0
  		  push!(tokeep, row)
			else
				push!(toremove, row)
  		end
  	end #if matrix dimension
  end # for
  if length(size(mat))==2
	  mat = mat[tokeep, :]
  elseif length(size(mat))==3
	  mat = mat[tokeep, :, :]
  elseif length(size(mat))==4
	  mat = mat[tokeep, :, :,:]
  end
  return (mat, tokeep, toremove)
end #fun

end #module
