import cython

import numpy as np
cimport numpy as np
from libcpp.string cimport string

from pytrt cimport TrtGooglenet
from pytrt cimport TrtMtcnnDet

cdef class PyTrtGooglenet:
    cdef TrtGooglenet *c_trtnet
    cdef tuple data_dims, prob_dims

    def __cinit__(PyTrtGooglenet self):
        self.c_trtnet = NULL

    def __init__(PyTrtGooglenet self, str engine_path, tuple shape0, tuple shape1):
        assert len(shape0) == 3 and len(shape1) == 3
        self.c_trtnet = new TrtGooglenet()
        self.data_dims = shape0
        self.prob_dims = shape1
        cdef int[:] v0 = np.array(shape0, dtype=np.intc)
        cdef int[:] v1 = np.array(shape1, dtype=np.intc)
        cdef string c_str = engine_path.encode('UTF-8')
        self.c_trtnet.initEngine(c_str, &v0[0], &v1[0])

    def forward(PyTrtGooglenet self, np.ndarray[np.float32_t, ndim=4] np_imgs not None):
        """Do a forward() computation on the input batch of imgs."""
        assert(np_imgs.shape[0] == 1)  # only accept batch_size = 1
        if not np_imgs.flags['C_CONTIGUOUS']:
            np_imgs = np.ascontiguousarray(np_imgs)
        np_prob = np.ascontiguousarray(
            np.zeros((self.batch_size,) + self.prob_dims, dtype=np.float32)
        )
        cdef float[:,:,:,::1] v_imgs = np_imgs
        cdef float[:,:,:,::1] v_prob = np_prob
        self.c_trtnet.forward(&v_imgs[0][0][0][0], &v_prob[0][0][0][0])
        return { 'prob': np_prob }

    def destroy(PyTrtGooglenet self):
        self.c_trtnet.destroy()


cdef class PyTrtMtcnn:
    cdef TrtMtcnnDet *c_trtnet
    cdef int batch_size
    cdef tuple data_dims, prob1_dims, boxes_dims

    def __cinit__(PyTrtMtcnn self):
        self.c_trtnet = NULL

    def __init__(PyTrtMtcnn self, str engine_path, tuple shape0, tuple shape1, tuple shape2):
        assert len(shape0) == 3 and len(shape1) == 3 and len(shape2) == 3
        self.c_trtnet = new TrtMtcnnDet()
        self.batch_size = 0
        self.data_dims  = shape0
        self.prob1_dims = shape1
        self.boxes_dims = shape2
        cdef int[:] v0 = np.array(shape0, dtype=np.intc)
        cdef int[:] v1 = np.array(shape1, dtype=np.intc)
        cdef int[:] v2 = np.array(shape2, dtype=np.intc)
        cdef string c_str = engine_path.encode('UTF-8')
        self.c_trtnet.initEngine(c_str, &v0[0], &v1[0], &v2[0])

    def set_batchsize(PyTrtMtcnn self, int batch_size):
        self.c_trtnet.setBatchSize(batch_size)
        self.batch_size = batch_size

    def forward(PyTrtMtcnn self, np.ndarray[np.float32_t, ndim=4] np_imgs not None):
        """Do a forward() computation on the input batch of imgs."""
        assert(np_imgs.shape[0] == self.batch_size)
        if not np_imgs.flags['C_CONTIGUOUS']:
            np_imgs = np.ascontiguousarray(np_imgs)
        np_probs = np.ascontiguousarray(
            np.zeros((self.batch_size,) + self.prob1_dims, dtype=np.float32)
        )
        np_boxes = np.ascontiguousarray(
            np.zeros((self.batch_size,) + self.boxes_dims, dtype=np.float32)
        )
        cdef float[:,:,:,::1] v_imgs  = np_imgs
        cdef float[:,:,:,::1] v_probs = np_probs
        cdef float[:,:,:,::1] v_boxes = np_boxes
        self.c_trtnet.forward(&v_imgs[0][0][0][0], &v_probs[0][0][0][0], &v_boxes[0][0][0][0])
        return { 'prob1': np_probs, 'boxes': np_boxes }

    def destroy(PyTrtMtcnn self):
        self.c_trtnet.destroy()