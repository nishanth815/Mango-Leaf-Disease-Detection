import tensorflow as tf, numpy as np
R="../ai_backend/"  # path to the original backend repo
m=tf.keras.models.load_model(R+"leaf_classifier/saved_models/leaf_non_leaf_best.keras")
t=tf.lite.TFLiteConverter.from_keras_model(m).convert()
open("assets/models/leaf_non_leaf.tflite","wb").write(t); print(len(t))
x=np.random.randint(0,255,(4,224,224,3)).astype(np.float32)
i=tf.lite.Interpreter(model_content=t);i.allocate_tensors()
d=i.get_input_details()[0];o=i.get_output_details()[0]
for k in range(4):
    i.set_tensor(d['index'],x[k:k+1]);i.invoke()
    print(float(i.get_tensor(o['index'])[0][0]), float(m.predict(x[k:k+1],verbose=0)[0][0]))
i=tf.lite.Interpreter(model_path=R+"output_files/mango_disease_int8.tflite",experimental_op_resolver_type=tf.lite.experimental.OpResolverType.BUILTIN_WITHOUT_DEFAULT_DELEGATES);i.allocate_tensors()
for k in ('shape','dtype','quantization'):print(k,i.get_input_details()[0][k],i.get_output_details()[0][k])
