function [L,S,errHist] = solver_split_SPCP(X,params)
% [L,S,errHist] = solver_split_SPCP(Y,params)
% Solves the problem
%   minimize_{U,V} lambda_L/2 (||U||_F^2 + ||V||_F^2) + phi(U,V)
%
% where
%
%   phi(U,V) = min_S .5|| U*V' + S - Y ||_F^2 + lambda_S ||S||_1.
%
%   errHist(:,1) is a record of runtime
%   errHist(:,2) is a record of the full objective (.f*resid^2 + lambda_L,
%      etc.)
%   errHist(:,3) is the output of params.errFcn if provided
%
% params is a structure with optional fields
%   errFcn     to compute objective or error (empty)
%   k          desired rank of L (10)
%   U0,V0      initial points for L0 = U0*V0' (random)
%   gpu        1 for gpu, 0 for cpu (0)
%   lambdaS    l1 penalty weight (0.8)
%   lambdaL    nuclear norm penalty weight (115)
%   
tic;

[m, n]   = size(X);
params.m = m;
params.n = n;

errFcn = setOpts(params,'errFcn',[]);
k      = setOpts(params,'k',10);
U0     = setOpts(params,'U0',randn(m,k));
V0     = setOpts(params,'V0',randn(n,k));
gpu    = setOpts(params,'gpu',0);
lambdaS = setOpts(params,'lambdaS',0.8); % default for demo_escalator
lambdaL = setOpts(params,'lambdaL',115); % default for demo_escalator

% check if we are on the GPU
if strcmp(class(X), 'gpuArray')
	gpu = 1;
end

if gpu
    U0 = gpuArray(U0);
    V0 = gpuArray(V0);
end

% initial point
R = [vec(U0); vec(V0)];

% set necessary parameters
params.lambdaS = lambdaS;
params.lambdaL = lambdaL;
params.gpu     = gpu;

% objective/gradient map for L-BFGS solver
ObjFunc = @(x)func_split_spcp(x,X,params,errFcn);

func_split_spcp();

% solve using L-BFGS
[x,~,~] = lbfgs_gpu(ObjFunc,R,params);

errHist=func_split_spcp();
% if ~isempty( errHist )
%     figure;
%     semilogy( errHist );
% end

% prepare output
U = reshape(x(1:m*k),m,k);
V = reshape(x(m*k+1:m*k+k*n),n,k);
S = func_split_spcp(x,X,params,'S');
S = reshape(S,m,n);

L = U*V';

end


function out = setOpts(options, opt, default)
    if isfield(options, opt)
        out = options.(opt);
    else
        out = default;
    end
end