namespace Skynet.DotNetClient.Gate.WS
{
    using System;
    using System.Text;
    using UnityEngine;
    using WebSocketSharp;

    public class Protocol
    {
        private SpStream _stream = new SpStream (1024);
        private SpRpc _rpc;

        private GateClient _client;
        private ProtocolLoader _loader;

        public Protocol(GateClient sc)
        {
            _client = sc;

            _loader = new ProtocolLoader();
            _rpc = _loader.CreateProto();
        }
        
        public SpStream Pack (string proto, int session, SpObject args)
        {
            _stream.Reset ();

            if (proto != "heartbeat")
            {
                Debug.Log("Send Request : " + proto + ", session : " + session);
            }

            _rpc.Request (proto, args, session, _stream);
            return _stream;
////            _socket.Send(_stream.Buffer, 0, _stream.Length);
//            byte[] bytes = new byte[_stream.Length+1];
//            
//            Array.Copy(_stream.Buffer, 0, bytes, 0, _stream.Length);
//            
//            string text  = Encoding.UTF8.GetString(bytes);
//            _socket.Send(text);
        }

        public void ProcessMessage(string data)
        {
            byte[] bytes = Encoding.UTF8.GetBytes(data);
            ProcessMessage(bytes);
        }
        
        public void ProcessMessage(byte[] bytes)
        {
            SpStream stream = new SpStream (bytes, 0, bytes.Length, bytes.Length);
            SpRpcResult result = _rpc.Dispatch (stream);
            _client.ProcessMessage (result);
        }
        
    }
}