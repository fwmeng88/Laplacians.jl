#=

Started by Dan Spielman.
Other contributors: xiao.shi@yale.edu,

Provides
  components :computes connected components, returns as a vector
  vecToComps : turns into an array with a list of vertices in each
  shortestPaths(mat, start) : returns an array of distances,
    and pointers to the node closest (parent array)


  kruskal(mat; kind=:min) : to get a max tree, use kind = :max
    returns it as a sparse matrix.

  sparsecut_cond(a, v[, k=1]) : sparse cut by conductance. given an
  adjacency matrix and an arbitrary vector, returns (val, S) pair,
  where val is the conductance of S, which is the sparsest cut found
  according to the procedure similar to the proof of Cheeger's
  Inequality. Does not consider vertex sets with fewer than k
  vertices.

  sparsecut_isop(a, v[, k=1]) : similar to above, but by isoperimetric
  number.

Internal:
  intHeap : used by shortestPaths,
    it is a heap in which the items are ints, and so can
    be removed quickly.



Unused:
  componentsSlow
  shortestPathsSlow

=#




function components{Tv,Ti}(mat::SparseMatrixCSC{Tv,Ti})
  n = mat.n

  order = Array(Ti,n)
  comp = zeros(Ti,n)

  # note that all of this casting is unnecessary.
  # but, some of it speeds up the code
  # I have not figured out the minimal necessary
  c::Ti = 0

  colptr::Array{Ti,1} = mat.colptr
  rowval::Array{Ti,1} = mat.rowval

  @inbounds for x in 1:n
    if (comp[x] == 0)
      c = c + 1
      comp[x] = c

      if colptr[x+1] > colptr[x]
        ptr::Ti = 1
        orderLen::Ti = 2
        order[ptr] = x

        while ptr < orderLen
          curNode = order[ptr]

          for ind in colptr[curNode]:(colptr[curNode+1]-1)
            nbr = rowval[ind]
            if comp[nbr] == 0
              comp[nbr] = c
              order[orderLen] = nbr
              orderLen += 1
            end # if
          end # for
          ptr += 1
        end # while
      end # if
    end

  end

  return comp
end # function


function vecToComps{Ti}(compvec::Array{Ti,1})
  nc = maximum(compvec)
  comps = Array(Array{Ti,1},nc)
  for i in 1:nc
    comps[i] = find(compvec.==i)
  end
  return comps
end # vecToComps

#end # module


function shortestPaths{Tv,Ti}(mat::SparseMatrixCSC{Tv,Ti}, start::Ti)
  n = mat.n
  visited = zeros(Bool,n)

  nh = intHeap(n)
  dists = nh.keys

  pArray = zeros(Ti,n)

  # dists[start] = 0.0
  intHeapAdd!(nh,start,0.0)
  pArray[start] = start

  while nh.nitems > 0
    v::Ti = intHeapPop!(nh)
    visited[v] = true

    dv = dists[v]
    for ind in mat.colptr[v]:(mat.colptr[v+1]-1)
      nbr = mat.rowval[ind]
      if !visited[nbr]
        newdist = dv + 1/mat.nzval[ind]
        if newdist < dists[nbr]
          dists[nbr] = newdist
          intHeapAdd!(nh,nbr,newdist)
          pArray[nbr] = v
        end # if
      end # if
    end # for

  end # while


  return copy(dists), pArray

end # shortestPaths

type intHeap{Tkey,Tind}
  keys::Array{Tkey,1}
  heap::Array{Tind,1}
  index::Array{Tind,1}
  nitems::Tind
end #intHeap

intHeap(n::Int64) = intHeap(Inf*ones(Float64,n),-ones(Int64,n),zeros(Int64,n),0)
intHeap(n::Int32) = intHeap(Inf*ones(Float32,n),-ones(Int32,n),zeros(Int32,n),0)

function intHeapAdd!{Tkey,Tind}(nh::intHeap, node::Tind, key::Tkey)
  if nh.index[node] > 0 # if already in the heap
    if key < nh.keys[node]
      intHeapSet!(nh, node, key)
    end

  else # if it really is new

    nhp = nh.nitems+1

    nh.keys[node] = key
    nh.heap[nhp] = node
    nh.index[node] = nhp
    nh.nitems = nhp

    intHeapUp!(nh, node)

  end
end # intHeapAdd!

function intHeapDown!{Tind}(nh::intHeap, node::Tind)
  pos = nh.index[node]
  key = nh.keys[node]
  leftPos = pos*2
  moved = true
  @inbounds while (leftPos <= nh.nitems) && moved
    moved = false
    rightPos = pos*2+1

    if rightPos > nh.nitems
      childPos = leftPos
      childNode = nh.heap[childPos]
      childKey = nh.keys[childNode]
    else
      leftNode = nh.heap[leftPos]
      leftKey = nh.keys[leftNode]
      rightNode = nh.heap[rightPos]
      rightKey = nh.keys[rightNode]

      if leftKey < rightKey
        childPos = leftPos
        childNode = leftNode
        childKey = leftKey
      else
        childPos = rightPos
        childNode = rightNode
        childKey = rightKey
      end
    end

    if childKey < key
      nh.heap[childPos] = node
      nh.heap[pos] = childNode
      nh.index[node] = childPos
      nh.index[childNode] = pos

      pos = childPos
      leftPos = pos*2
      moved = true
    end

  end #while
end # intHeapDown!

function intHeapPop!(nh::intHeap)
  minNode = nh.heap[1]

  nh.index[minNode] = 0

  @inbounds if (nh.nitems > 1)
    node = nh.heap[nh.nitems]
    nh.heap[1] = node
    nh.index[node] = 1
    intHeapDown!(nh, node)
  end
  nh.nitems = nh.nitems - 1

  return minNode
end # intHeapPop!

function intHeapUp!{Tind}(nh::intHeap, node::Tind)
  pos = nh.index[node]
  moved = true

  @inbounds while (pos > 1) && moved
    key = nh.keys[node]

    parentPos = div(pos,2)
    parentNode = nh.heap[parentPos]
    parentKey = nh.keys[parentNode]

    moved = false

    if (parentKey > key)
      nh.heap[parentPos] = node
      nh.heap[pos] = parentNode
      nh.index[node] = parentPos
      nh.index[parentNode] = pos
      pos = parentPos
      moved = true
    end
  end

end # intHeapUp!

function intHeapSort(x::Array{Float64,1})
  n = length(x)
  nh = intHeap(n)

  @inbounds for i in 1:n
    intHeapAdd!(nh, i, x[i])
  end

  out = zeros(Float64,n)
  @inbounds for i in 1:n
    out[i] = nh.keys[intHeapPop!(nh)]
  end

  return out

end # intHeapSort


function intHeapSort(nh::intHeap)
  n = length(nh.keys)

  out = zeros(Float64,n)
  for i in 1:n
    out[i] = nh.keys[intHeapPop!(nh)]
  end

  return out

end # intHeapSort

function intHeapSet!{Tkey,Tind}(nh::intHeap, node::Tind, key::Tkey)
  oldKey = nh.keys[node]
  nh.keys[node] = key

  if (key < oldKey)
    intHeapUp!(nh,node)
  else
    intHeapDown!(nh,node)
  end
end # intHeapSet!


function kruskal{Tv,Ti}(mat::SparseMatrixCSC{Tv,Ti}; kind=:min)
  n = size(mat)[1]
  (ai,aj,av) = findnz(triu(mat))
  if (kind == :min)
    ord = sortperm(av)
  else
    ord = sortperm(av, rev=true)
  end

  comps = IntDisjointSets(n)

  treeinds = zeros(Ti,n-1)
  numintree = 0
  for i in ord
    if !DataStructures.in_same_set(comps,ai[i],aj[i])
      numintree = numintree+1
      treeinds[numintree] = i
      DataStructures.union!(comps,ai[i],aj[i])
    end
  end

  tree = sparse(ai[treeinds],aj[treeinds],av[treeinds],n,n)
  tree = tree + tree'

  return tree

end


function prim(mat::SparseMatrixCSC)


  nVertices = mat.n
  nh = intHeap(nVertices)

  visited = zeros(Bool, nVertices)
  associatedEdges = zeros(Int64, nVertices)


  treeInds = zeros(Int64, nVertices)


  visited[1] = true
  associatedEdges[1] = -1

  for vInd in 2:nVertices
    intHeapAdd!(nh, vInd, Inf)
  end #for


  for eInd in mat.colptr[1]:(mat.colptr[2]-1)
    intHeapSet!(nh, mat.rowval[eInd], mat.nzval[eInd])
    associatedEdges[mat.rowval[eInd]] = eInd #this won't work if there are multiple edges between two vertices... is that possible?
  end #for

  for x in 1:nVertices-1

    vInd = intHeapPop!(nh)
    while visited[vInd]
      vInd = intHeapPop!(nh)
    end #while
    visited[vInd] = true
    treeInds[vInd] = associatedEdges[vInd]
    associatedEdges[vInd] = -1

    for eInd in mat.colptr[vInd]:(mat.colptr[vInd+1]-1)
      edgeWeight = mat.nzval[eInd]
      otherVert = mat.rowval[eInd]
      previousEdgeIndex = associatedEdges[otherVert]
      if previousEdgeIndex == -1
        continue
      end #if
      if (previousEdgeIndex == 0 || edgeWeight < mat.nzval[previousEdgeIndex])

        intHeapSet!(nh, otherVert, edgeWeight)
        associatedEdges[otherVert] = eInd
      end #if
    end # for
  end #for


  t2 = treeInds[2:nVertices];

  (ai,aj,av) = findnz(mat);
  tr2 = sparse(ai[t2],aj[t2],av[t2],nVertices,nVertices)
  tr2 = tr2 + tr2';

  return tr2


end #prim


#################################################################
#             OLD AND UNUSED CODE
#################################################################


function componentsSlow{Tv,Ti}(mat::SparseMatrixCSC{Tv,Ti})
  n = mat.n

  order = Array(Ti,n)
  comp = zeros(Ti,n)

  # note that all of this casting is unnecessary.
  # but, some of it speeds up the code
  # I have not figured out the minimal necessary
  c::Ti = 0

  for x in 1:n

    if (comp[x] == 0)
      c = c + 1
      comp[x] = c

      if deg(mat,x) > 0
       ptr::Ti = 1
       orderLen::Ti = 2
       order[ptr] = x

       while ptr < orderLen
         curNode = order[ptr]

         for i in 1:deg(mat,curNode)
           nbr = nbri(mat,curNode,i)
           if comp[nbr] == 0
             comp[nbr] = c
             order[orderLen] = nbr
             orderLen += 1
           end # if
         end # for
         ptr += 1
       end # while
      end # if
    end

  end

  return comp
end # function





function shortestPathsSlow(mat::SparseMatrixCSC{Float64,Int64}, start::Int64)
  n = mat.n
  visited = zeros(Bool,n)

  pq = Collections.PriorityQueue{Int64,Float64}()
  dists = Inf*ones(Float64,n)

  pArray = zeros(Int64,n)

  dists[start] = 0.0
  pq[start] = 0.0
  pArray[start] = start

  while !isempty(pq)
    v::Int64 = Collections.dequeue!(pq)
    visited[v] = true

    dv = dists[v]
    for ind in mat.colptr[v]:(mat.colptr[v+1]-1)
      nbr = mat.rowval[ind]
      if !visited[nbr]
        newdist = dv + 1/mat.nzval[ind]
        if newdist < dists[nbr]
          dists[nbr] = newdist
          pq[nbr] = newdist
          pArray[nbr] = v
        end # if
      end # if
    end # for

  end # while


  return dists, pArray

end # shortestPaths

# sparse cuts
function sparsecut_cond(a, v, k = 1)
  (n, m) = size(a)
  if (n != m)
    error("adjacency matrix must be square!")
  end

  l = length(v)
  if (l != n)
    error("initial vector must be n*1")
  end

  if (k > n / 2)
    error("k is too large!")
  end

  perm = sortperm(v) # get the permutation for sorted v
  # vp = v[perm] # the permuted vector
  ap = a[perm, perm] # adjacency matrix after permutation
  aps = sum(ap, 1) # d(u) = weighted degree of each vertex

  apu = triu(ap) # upper triangular permuted adjacency matrix
  apus = sum(apu, 1) # sum each column

  sumwt = cumsum(aps, 2) # sumwt[u] = sum_{u=1}^{i} d(u)
  edgein = cumsum(apus[1:n]) # sum of edge weights with in S

  nh = n - k
  conductance = (sumwt[k:nh]-2edgein[k:nh]) ./ min(sumwt[k:nh], sumwt[n]-sumwt[k:nh])

  (val, ind) = findmin(conductance)
  return val, perm[1:(ind+k-1)]
end

function sparsecut_isop(a, v, k=1)
  (n, m) = size(a)
  if (n != m)
    error("adjacency matrix must be square!")
  end

  l = length(v)
  if (l != n)
    error("initial vector must be n*1")
  end

  if (k > n / 2)
    error("k is too large!")
  end

  perm = sortperm(v) # get the permutation for sorted v
  # vp = v[perm] # the permuted vector
  ap = a[perm, perm] # adjacency matrix after permutation
  aps = sum(ap, 1) # d(u) = weighted degree of each vertex

  apu = triu(ap) # upper triangular permuted adjacency matrix
  apus = sum(apu, 1) # sum each column

  sumwt = cumsum(aps, 2) # sumwt[u] = sum_{u=1}^{i} d(u)
  edgein = cumsum(apus[1:n]) # sum of edge weights with in S

  nh = n - k
  isop = (sumwt[k:nh]-2edgein[k:nh]) ./ linspace(k, nh, nh-k+1)

  (val, ind) = findmin(isop)
  return val, perm[1:(ind+k-1)]
end